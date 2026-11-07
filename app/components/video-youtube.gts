import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";

import { modifier } from "ember-modifier";
import { getPromiseState } from "reactiveweb/get-promise-state";

import { type Player, YouTubePlayer } from "#utils/player.ts";
import { loadYouTubeApi } from "#utils/youtube.ts";

interface Signature {
  Args: {
    id: string;
    onReady: (player: Player) => void;
  };
}

/**
 * Error codes of the YouTube player:
 * https://developers.google.com/youtube/iframe_api_reference#onError
 */
const ERRORS: Record<number, string> = {
  2: "That video id is not valid.",
  5: "The YouTube player cannot play this video in this browser.",
  100: "That video does not exist, or it is private.",
  101: "The owner of that video does not allow it on other sites.",
  150: "The owner of that video does not allow it on other sites.",
};

export class YouTubeVideo extends Component<Signature> {
  api = loadYouTubeApi();

  @tracked playerError: string | undefined;

  get state() {
    return getPromiseState(this.api);
  }

  get error() {
    if (this.playerError) return this.playerError;

    const { error } = this.state;

    if (!error) return undefined;

    return error instanceof Error ? error.message : String(error);
  }

  /**
   * The YouTube API replaces its element with an iframe,
   * so it gets an element that Ember does not render.
   */
  mount = modifier((container: HTMLElement) => {
    const target = document.createElement("div");
    let player: YT.Player | undefined;
    let destroyed = false;

    container.append(target);

    void this.api.then((YT) => {
      if (destroyed) return;

      player = new YT.Player(target, {
        videoId: this.args.id,
        width: "100%",
        height: "100%",
        playerVars: {
          /**
           * The number keys of YouTube jump to a part of the video.
           * This app uses the number keys to go back some seconds.
           */
          disablekb: 1,
          playsinline: 1,
          rel: 0,

          /**
           * The app has its own controls, also over the video in theatre mode and full screen.
           */
          controls: 0,
        },
        events: {
          onReady: (event) => this.args.onReady(new YouTubePlayer(event.target)),
          onError: (event) => {
            this.playerError = ERRORS[event.data] ?? `The YouTube player stopped (${event.data}).`;
          },
        },
      });
    });

    return () => {
      destroyed = true;
      player?.destroy();
      container.replaceChildren();
    };
  });

  <template>
    {{#if this.error}}
      <p class="replay__error" role="alert">{{this.error}}</p>
    {{else}}
      <div class="replay__media replay__youtube" data-test-youtube {{this.mount}}></div>
    {{/if}}
  </template>
}
