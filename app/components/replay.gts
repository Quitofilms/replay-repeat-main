import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";

import { modifier } from "ember-modifier";
import { castToBoolean } from "ember-primitives/qp";
import { Button, RangeSlider, ToggleButton } from "nvp.ui";

import { driveMediaUrl, isDriveDownloadUrl } from "#utils/drive.ts";
import { History } from "#utils/history.ts";
import { formatSeconds, PARAMS, secondsOf } from "#utils/params.ts";
import { formatTime } from "#utils/time.ts";
import Fullscreen from "~icons/mdi/fullscreen";
import FullscreenExit from "~icons/mdi/fullscreen-exit";
import Minus from "~icons/mdi/minus";
import Plus from "~icons/mdi/plus";
import Redo from "~icons/mdi/redo";
import Repeat from "~icons/mdi/repeat";
import RepeatOff from "~icons/mdi/repeat-off";
import SkipPrevious from "~icons/mdi/skip-previous";
import TheatreIcon from "~icons/mdi/television";
import Undo from "~icons/mdi/undo";
import VolumeHigh from "~icons/mdi/volume-high";
import VolumeOff from "~icons/mdi/volume-off";

import { DriveVideo } from "./drive-video.gts";
import { Shortcuts } from "./shortcuts.gts";
import { VideoFile } from "./video-file.gts";
import { YouTubeVideo } from "./video-youtube.gts";

import type UrlStateService from "#services/url-state.ts";
import type { Player } from "#utils/player.ts";
import type { Source } from "#utils/source.ts";

interface Signature {
  Args: {
    source: Source;
  };
}

/**
 * Markers move in tenths of a second.
 */
const STEP = 0.1;

/**
 * The speeds that YouTube supports, so files and YouTube have the same steps.
 */
const RATES = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 1.75, 2];

interface Markers {
  start: number;
  end: number | undefined;
}

const sameMarkers = (a: Markers, b: Markers) => a.start === b.start && a.end === b.end;

const formatRate = (rate: number) => `${rate}×`;

/**
 * How the player shows: in the page, across the window, or full screen.
 */
type View = "normal" | "theatre" | "fullscreen";

/**
 * In theatre mode and full screen, the controls over the video
 * fade out after this long without a pointer move or a key press.
 */
const IDLE_MS = 2500;

/**
 * After a seek, a player can report the old time for a few frames.
 * The loop waits this long before it checks the time again.
 */
const SEEK_SETTLE_MS = 250;

function toStep(seconds: number) {
  return Math.round(seconds / STEP) * STEP;
}

/**
 * Keys in these elements are text for the element, not shortcuts.
 * A range input, such as a marker thumb, takes no text.
 */
const TEXT_ENTRY =
  "textarea, select, input:not([type=range], [type=checkbox], [type=radio], [type=button], [type=submit], [type=file])";

function isTyping(target: EventTarget | null) {
  if (!(target instanceof HTMLElement)) return false;

  return target.isContentEditable || target.closest(TEXT_ENTRY) !== null;
}

const playheadStyle = (percent: number) => htmlSafe(`left: ${percent}%`);

/**
 * The state of a replay is in the URL: the loop, its markers, and the speed.
 * The player's time and play state are not, because they change all the time.
 */
export class Replay extends Component<Signature> {
  @service("url-state") declare urlState: UrlStateService;

  @tracked player: Player | undefined;
  @tracked now = 0;
  @tracked duration = 0;
  @tracked paused = true;
  @tracked volume = 1;
  @tracked muted = false;

  /**
   * Only `show` changes the view.
   * Full screen starts and ends in `fullscreenchange`,
   * because the browser can also leave it on its own, for example on Escape.
   */
  @tracked view: View = "normal";

  /**
   * The view that full screen goes back to.
   */
  #afterFullscreen: Exclude<View, "fullscreen"> = "normal";

  /**
   * The controls over the video are hidden, and so is the cursor.
   */
  @tracked idle = false;
  @tracked overControls = false;

  /**
   * The markers while a thumb moves. The URL gets them once, when the move ends,
   * so a drag is one history entry.
   */
  @tracked draft: Markers | undefined;

  markers = new History<Markers>({ start: 0, end: undefined }, sameMarkers);

  #seekedAt = 0;
  #activeAt = 0;
  #playerElement: HTMLElement | undefined;

  get theatre() {
    return this.view === "theatre";
  }

  get fullscreen() {
    return this.view === "fullscreen";
  }

  /**
   * The controls go over the video, and hide when nothing happens.
   */
  get overlay() {
    return this.view !== "normal";
  }

  /**
   * The speed that the player has from this app, and when it got it.
   * A different speed in the player after that came from YouTube's own menu.
   */
  #appliedRate = 1;
  #rateSetAt = 0;

  get looping() {
    return castToBoolean(this.urlState.param(PARAMS.loop));
  }

  get chosenStart() {
    return this.draft?.start ?? secondsOf(this.urlState.param(PARAMS.loopStart)) ?? 0;
  }

  /**
   * `undefined` means the end of the video,
   * which is unknown for YouTube until the video loads.
   */
  get chosenEnd() {
    return this.draft ? this.draft.end : secondsOf(this.urlState.param(PARAMS.loopEnd));
  }

  get rate() {
    const rate = Number.parseFloat(this.urlState.param(PARAMS.speed) ?? "");

    const known = RATES.some((slower) => slower <= rate) && RATES.some((faster) => faster >= rate);

    return known ? rate : 1;
  }

  writeMarkers(markers: Markers) {
    this.urlState.update({
      [PARAMS.loopStart]: markers.start > 0 ? formatSeconds(markers.start) : null,
      [PARAMS.loopEnd]: markers.end === undefined ? null : formatSeconds(markers.end),
    });
  }

  get file() {
    return this.args.source.kind === "file" ? this.args.source.file : undefined;
  }

  get youTubeId() {
    return this.args.source.kind === "youtube" ? this.args.source.id : undefined;
  }

  get driveId() {
    return this.args.source.kind === "drive" ? this.args.source.id : undefined;
  }

  get driveDownloadUrl() {
    if (this.args.source.kind !== "drive") return undefined;
    return isDriveDownloadUrl(this.args.source.downloadUrl)
      ? this.args.source.downloadUrl
      : driveMediaUrl(this.args.source.id);
  }

  get loopStart() {
    return Math.min(this.chosenStart, this.duration);
  }

  get loopEnd() {
    return Math.min(this.chosenEnd ?? this.duration, this.duration);
  }

  ready = (player: Player) => {
    this.player = player;
    this.duration = player.duration;
    this.volume = player.volume;
    this.muted = player.muted;
  };

  seek(seconds: number) {
    if (!this.player) return;

    this.#seekedAt = performance.now();
    this.player.seek(seconds);
    this.now = seconds;
  }

  back = (seconds: number) => {
    const floor = this.looping ? this.loopStart : 0;

    this.seek(Math.max(this.now - seconds, floor));
  };

  togglePlay = () => {
    if (!this.player) return;

    if (this.player.paused) {
      this.player.play();
    } else {
      this.player.pause();
    }
  };

  toggleLoop = () => {
    this.urlState.update({ [PARAMS.loop]: this.looping ? null : "1" });
  };

  toLoopStart = () => {
    this.seek(this.loopStart);
  };

  toggleMute = () => {
    this.muted = !this.muted;
    this.player?.setMuted(this.muted);
  };

  /**
   * Moving the volume up from silence also unmutes.
   */
  changeVolume = (event: Event) => {
    const volume = Number((event.currentTarget as HTMLInputElement).value);

    this.volume = volume;
    this.player?.setVolume(volume);

    if (this.muted && volume > 0) this.toggleMute();
  };

  /**
   * Every change of view goes through here.
   *
   * - Into full screen, the view to come back to is remembered.
   * - Out of full screen, to any view, full screen ends first,
   *   and `fullscreenChanged` shows that view.
   * - A browser can refuse full screen, for example without a click or a key press first.
   */
  show(view: View) {
    this.activity();

    if (view === this.view) return;

    if (view === "fullscreen") {
      this.#afterFullscreen = this.view === "theatre" ? "theatre" : "normal";
      void this.#playerElement?.requestFullscreen().catch(() => {});

      return;
    }

    if (this.view === "fullscreen") {
      this.#afterFullscreen = view;
      void document.exitFullscreen().catch(() => {});

      return;
    }

    this.view = view;
    this.alignTheatre();
  }

  toggleTheatre = () => {
    this.show(this.theatre ? "normal" : "theatre");
  };

  toggleFullscreen = () => {
    this.show(this.fullscreen ? this.#afterFullscreen : "fullscreen");
  };

  fullscreenChanged = () => {
    const entered =
      Boolean(this.#playerElement) && document.fullscreenElement === this.#playerElement;

    this.activity();

    if (entered) {
      this.view = "fullscreen";
    } else if (this.fullscreen) {
      this.view = this.#afterFullscreen;
      this.alignTheatre();
    }
  };

  /**
   * Theatre mode sizes the player to the window, so the player goes to the top of it,
   * also when theatre mode comes back after full screen.
   * The frame lets the player take its theatre size first.
   */
  alignTheatre() {
    if (!this.theatre) return;

    requestAnimationFrame(() => this.#playerElement?.scrollIntoView({ block: "start" }));
  }

  activity = () => {
    this.#activeAt = performance.now();

    if (this.idle) this.idle = false;
  };

  enterControls = () => {
    this.overControls = true;
  };

  leaveControls = () => {
    this.overControls = false;
    this.activity();
  };

  setRate(rate: number) {
    this.player?.setRate(rate);
    this.writeRate(rate);
  }

  writeRate(rate: number) {
    this.#appliedRate = rate;
    this.#rateSetAt = performance.now();
    this.urlState.update({ [PARAMS.speed]: rate === 1 ? null : String(rate) });
  }

  get canSlowDown() {
    return RATES.some((rate) => rate < this.rate);
  }

  get canSpeedUp() {
    return RATES.some((rate) => rate > this.rate);
  }

  slower = () => {
    this.setRate(RATES.findLast((rate) => rate < this.rate) ?? this.rate);
  };

  faster = () => {
    this.setRate(RATES.find((rate) => rate > this.rate) ?? this.rate);
  };

  /**
   * Live while a marker moves. `recordMarkers` makes the undo step when the move ends.
   */
  setMarkers = (start: number, end: number) => {
    this.draft = { start, end };
  };

  recordMarkers = () => {
    const markers = { start: this.chosenStart, end: this.chosenEnd };

    this.draft = undefined;
    this.markers.record(markers);
    this.writeMarkers(markers);
  };

  applyMarkers(markers: Markers | undefined) {
    if (markers) this.writeMarkers(markers);
  }

  undo = () => {
    this.applyMarkers(this.markers.undo());
  };

  redo = () => {
    this.applyMarkers(this.markers.redo());
  };

  /**
   * A new value for the markers, as one undo step.
   */
  moveMarkers(markers: Markers) {
    this.markers.record(markers);
    this.writeMarkers(markers);
  }

  markStart = () => {
    this.moveMarkers({
      start: Math.max(0, Math.min(toStep(this.now), this.loopEnd - STEP)),
      end: this.chosenEnd,
    });
  };

  markEnd = () => {
    this.moveMarkers({
      start: this.chosenStart,
      end: Math.min(this.duration, Math.max(toStep(this.now), this.loopStart + STEP)),
    });
  };

  resetMarkers = () => {
    this.moveMarkers({ start: 0, end: undefined });
  };

  tick = () => {
    const { player } = this;

    if (!player) return;

    const time = player.currentTime;

    if (time !== this.now) this.now = time;
    if (player.duration !== this.duration) this.duration = player.duration;

    if (player.paused !== this.paused) {
      this.paused = player.paused;

      if (!player.paused) this.started(time);
    }

    this.syncRate(player);
    this.syncIdle();

    if (!this.looping || performance.now() - this.#seekedAt < SEEK_SETTLE_MS) return;

    /**
     * A video that the user paused stays where it is.
     * A video at its end is paused too, but it must loop.
     */
    if (player.paused && !player.ended) return;

    if (time >= this.loopEnd || player.ended) {
      this.seek(this.loopStart);
      player.play();
    }
  };

  /**
   * Playback that starts outside the loop starts at the loop start,
   * for example on a link with `loop_start`, where the video is at 0:00.
   *
   * This runs for any way to play: the Play button, the K key,
   * and YouTube's own controls.
   */
  started(time: number) {
    if (!this.looping) return;
    if (time >= this.loopStart && time < this.loopEnd) return;

    this.seek(this.loopStart);
  }

  /**
   * The URL holds the speed. A new speed there goes to the player.
   * A new speed from YouTube's own menu goes to the URL.
   *
   * YouTube applies a speed a few frames later,
   * so the player is not read again until it settled.
   */
  syncRate(player: Player) {
    if (this.rate !== this.#appliedRate) {
      player.setRate(this.rate);
      this.#appliedRate = this.rate;
      this.#rateSetAt = performance.now();

      return;
    }

    if (performance.now() - this.#rateSetAt < SEEK_SETTLE_MS) return;
    if (player.rate !== this.#appliedRate) this.writeRate(player.rate);
  }

  /**
   * The controls stay while the video is paused, or while the pointer is on them.
   */
  syncIdle() {
    const idle =
      this.overlay &&
      !this.paused &&
      !this.overControls &&
      performance.now() - this.#activeAt > IDLE_MS;

    if (idle !== this.idle) this.idle = idle;
  }

  onKey = (event: KeyboardEvent) => {
    this.activity();

    if (isTyping(event.target)) return;
    if (event.altKey) return;

    if (event.ctrlKey || event.metaKey) {
      this.onUndoKey(event);

      return;
    }

    if (event.key >= "0" && event.key <= "9" && event.key.length === 1) {
      event.preventDefault();
      this.back(event.key === "0" ? 10 : Number(event.key));

      return;
    }

    switch (event.key) {
      case "[":
        this.markStart();

        break;
      case "]":
        this.markEnd();

        break;
      case "l":
      case "L":
        this.toggleLoop();

        break;
      case "k":
      case "K":
        this.togglePlay();

        break;
      case "r":
      case "R":
        this.toLoopStart();

        break;
      case "<":
        this.slower();

        break;
      case ">":
        this.faster();

        break;
      case "m":
      case "M":
        this.toggleMute();

        break;
      case "t":
      case "T":
        this.toggleTheatre();

        break;
      case "f":
      case "F":
        this.toggleFullscreen();

        break;
      case "Escape":
        /**
         * In full screen, the browser handles Escape itself.
         */
        if (!this.theatre) return;

        this.show("normal");

        break;
      default:
        return;
    }

    event.preventDefault();
  };

  /**
   * Ctrl or Cmd with Z undoes, with Shift+Z or Y it redoes, as in other apps.
   */
  onUndoKey(event: KeyboardEvent) {
    const key = event.key.toLowerCase();

    if (key === "z" && !event.shiftKey) {
      this.undo();
    } else if ((key === "z" && event.shiftKey) || key === "y") {
      this.redo();
    } else {
      return;
    }

    event.preventDefault();
  }

  /**
   * Runs for as long as the replay is on the page:
   *
   * - reads the time of the player on each frame, for the playhead and the loop
   * - listens for shortcut keys on the whole page
   * - takes the focus back from the YouTube iframe, which keeps key presses for itself
   * - follows full screen, which the browser can also leave on its own
   */
  connect = modifier((element: HTMLElement) => {
    const loop = () => {
      this.tick();
      frame = requestAnimationFrame(loop);
    };
    let frame = requestAnimationFrame(loop);

    const onBlur = () => {
      setTimeout(() => {
        if (
          document.activeElement instanceof HTMLIFrameElement &&
          element.contains(document.activeElement)
        ) {
          element.focus();
        }
      });
    };

    document.addEventListener("keydown", this.onKey);
    document.addEventListener("fullscreenchange", this.fullscreenChanged);
    window.addEventListener("blur", onBlur);

    return () => {
      cancelAnimationFrame(frame);
      document.removeEventListener("keydown", this.onKey);
      document.removeEventListener("fullscreenchange", this.fullscreenChanged);
      window.removeEventListener("blur", onBlur);
    };
  });

  /**
   * The element that goes full screen: the video and the controls.
   */
  playerElement = modifier((element: HTMLElement) => {
    this.#playerElement = element;

    return () => {
      this.#playerElement = undefined;
    };
  });

  <template>
    <section
      class="replay"
      tabindex="-1"
      aria-label="Player"
      data-theatre={{this.theatre}}
      data-test-replay
      {{this.connect}}
    >
      <div
        class="replay__player"
        data-overlay={{this.overlay}}
        data-idle={{this.idle}}
        data-test-player
        {{this.playerElement}}
        {{on "pointermove" this.activity}}
        {{on "pointerdown" this.activity}}
      >
        <div class="replay__stage">
          {{#if this.file}}
            <VideoFile @file={{this.file}} @onReady={{this.ready}} />
          {{else if this.youTubeId}}
            <YouTubeVideo @id={{this.youTubeId}} @onReady={{this.ready}} />
          {{else if this.driveId}}
            <DriveVideo
              @id={{this.driveId}}
              @downloadUrl={{this.driveDownloadUrl}}
              @onReady={{this.ready}}
            />
          {{/if}}

          {{#if this.player}}
            {{! Over the video, so that pointer moves reach the app, also over YouTube's iframe.
                The buttons do the same for the keyboard. }}
            {{! template-lint-disable no-invalid-interactive }}
            <div
              class="replay__surface"
              data-test-surface
              {{on "click" this.togglePlay}}
              {{on "dblclick" this.toggleFullscreen}}
            ></div>
          {{/if}}
        </div>

        {{#if this.player}}
          <div
            class="replay__controls surface {{if this.overlay 'theme-dark'}}"
            data-test-controls
            {{on "pointerenter" this.enterControls}}
            {{on "pointerleave" this.leaveControls}}
          >
            <div class="replay__status">
              <span class="replay__time" data-test-time>
                <span data-test-now>{{formatTime this.now}}</span>
                /
                <span data-test-duration>{{formatTime this.duration}}</span>
              </span>

              {{#if this.looping}}
                <span class="replay__looping" data-test-looping>
                  <Repeat aria-hidden="true" />
                  Looping
                  {{formatTime this.loopStart}}
                  to
                  {{formatTime this.loopEnd}}
                </span>
              {{/if}}
            </div>

            <RangeSlider
              class="replay__markers"
              data-looping={{this.looping}}
              @label="Loop markers"
              @startLabel="Loop start"
              @endLabel="Loop end"
              @max={{this.duration}}
              @step={{STEP}}
              @start={{this.loopStart}}
              @end={{this.loopEnd}}
              @onChange={{this.setMarkers}}
              @onCommit={{this.recordMarkers}}
              @formatValue={{formatTime}}
              as |track|
            >
              <span
                class="replay__playhead"
                style={{playheadStyle (track.position this.now)}}
              ></span>
            </RangeSlider>

            <div class="replay__buttons">
              <div class="replay__playback">
                <div role="group" aria-label="Playback">
                  <Button @variant="primary" @onClick={{this.togglePlay}} data-test-play>
                    {{if this.paused "Play" "Pause"}}
                  </Button>
                  <ToggleButton
                    @pressed={{this.looping}}
                    @variant={{if this.looping "primary"}}
                    @onClick={{this.toggleLoop}}
                    data-test-loop
                  >
                    {{#if this.looping}}
                      <Repeat aria-hidden="true" />
                    {{else}}
                      <RepeatOff aria-hidden="true" />
                    {{/if}}
                    Loop
                  </ToggleButton>
                </div>

                <div role="group" aria-label="Speed" class="replay__speed">
                  <Button
                    aria-label="Slower"
                    @disabled={{unless this.canSlowDown "Already the slowest speed"}}
                    @onClick={{this.slower}}
                    data-test-slower
                  ><Minus aria-hidden="true" /></Button>
                  <span class="replay__rate" data-test-rate>{{formatRate this.rate}}</span>
                  <Button
                    aria-label="Faster"
                    @disabled={{unless this.canSpeedUp "Already the fastest speed"}}
                    @onClick={{this.faster}}
                    data-test-faster
                  ><Plus aria-hidden="true" /></Button>
                </div>

                <Button @onClick={{this.toLoopStart}} data-test-to-loop-start>
                  <:start><SkipPrevious aria-hidden="true" /></:start>
                  <:default>Go to loop start</:default>
                </Button>
              </div>

              <div role="group" aria-label="Loop markers" class="replay__marker-buttons">
                <Button @onClick={{this.markStart}}>Set start here</Button>
                <Button @onClick={{this.markEnd}}>Set end here</Button>
                <Button
                  aria-label="Undo"
                  @disabled={{unless this.markers.canUndo "No marker move to undo"}}
                  @onClick={{this.undo}}
                  data-test-undo
                ><Undo aria-hidden="true" /></Button>
                <Button
                  aria-label="Redo"
                  @disabled={{unless this.markers.canRedo "No marker move to redo"}}
                  @onClick={{this.redo}}
                  data-test-redo
                ><Redo aria-hidden="true" /></Button>
                <Button @variant="bare" @onClick={{this.resetMarkers}} data-test-reset>Reset markers</Button>
              </div>

              <div role="group" aria-label="View" class="replay__view">
                <Button
                  aria-label={{if this.muted "Unmute" "Mute"}}
                  @onClick={{this.toggleMute}}
                  data-test-mute
                >
                  {{#if this.muted}}
                    <VolumeOff aria-hidden="true" />
                  {{else}}
                    <VolumeHigh aria-hidden="true" />
                  {{/if}}
                </Button>
                <input
                  class="replay__volume"
                  type="range"
                  min="0"
                  max="1"
                  step="0.05"
                  value={{if this.muted 0 this.volume}}
                  aria-label="Volume"
                  data-test-volume
                  {{on "input" this.changeVolume}}
                />
                <ToggleButton
                  @pressed={{this.theatre}}
                  @onClick={{this.toggleTheatre}}
                  aria-label="Theatre mode"
                  data-test-theatre
                ><TheatreIcon aria-hidden="true" /></ToggleButton>
                <Button
                  aria-label={{if this.fullscreen "Exit full screen" "Full screen"}}
                  @onClick={{this.toggleFullscreen}}
                  data-test-fullscreen
                >
                  {{#if this.fullscreen}}
                    <FullscreenExit aria-hidden="true" />
                  {{else}}
                    <Fullscreen aria-hidden="true" />
                  {{/if}}
                </Button>
              </div>
            </div>
          </div>
        {{/if}}
      </div>

      {{#if this.player}}
        <Shortcuts />
      {{/if}}
    </section>
  </template>
}
