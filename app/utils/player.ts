/**
 * The controls of a video, the same for a file on disk and for YouTube.
 */
export interface Player {
  readonly currentTime: number;
  readonly duration: number;
  readonly paused: boolean;
  readonly ended: boolean;

  /**
   * The playback speed: 1 is normal, 0.5 is half speed.
   */
  readonly rate: number;
  setRate(rate: number): void;

  /**
   * From 0 to 1. Muting keeps the volume for when the sound comes back.
   */
  readonly volume: number;
  readonly muted: boolean;
  setVolume(volume: number): void;
  setMuted(muted: boolean): void;
  seek(seconds: number): void;
  play(): void;
  pause(): void;
}

export class FilePlayer implements Player {
  #video: HTMLVideoElement;

  constructor(video: HTMLVideoElement) {
    this.#video = video;
  }

  get currentTime() {
    return this.#video.currentTime;
  }

  get duration() {
    const { duration } = this.#video;

    return Number.isFinite(duration) ? duration : 0;
  }

  get paused() {
    return this.#video.paused;
  }

  get ended() {
    return this.#video.ended;
  }

  get rate() {
    return this.#video.playbackRate;
  }

  setRate(rate: number) {
    this.#video.playbackRate = rate;
  }

  get volume() {
    return this.#video.volume;
  }

  get muted() {
    return this.#video.muted;
  }

  setVolume(volume: number) {
    this.#video.volume = volume;
  }

  setMuted(muted: boolean) {
    this.#video.muted = muted;
  }

  seek(seconds: number) {
    this.#video.currentTime = seconds;
  }

  play() {
    /**
     * A browser can refuse to play, for example before any user input.
     * The play button stays available, so there is nothing else to do.
     */
    this.#video.play().catch(() => {});
  }

  pause() {
    this.#video.pause();
  }
}

export class YouTubePlayer implements Player {
  #player: YT.Player;

  constructor(player: YT.Player) {
    this.#player = player;
  }

  get currentTime() {
    return this.#player.getCurrentTime();
  }

  get duration() {
    return this.#player.getDuration();
  }

  get paused() {
    const state = this.#player.getPlayerState();

    return state !== YT.PlayerState.PLAYING && state !== YT.PlayerState.BUFFERING;
  }

  get ended() {
    return this.#player.getPlayerState() === YT.PlayerState.ENDED;
  }

  get rate() {
    return this.#player.getPlaybackRate();
  }

  setRate(rate: number) {
    this.#player.setPlaybackRate(rate);
  }

  /**
   * YouTube counts the volume from 0 to 100.
   */
  get volume() {
    return this.#player.getVolume() / 100;
  }

  get muted() {
    return this.#player.isMuted();
  }

  setVolume(volume: number) {
    this.#player.setVolume(Math.round(volume * 100));
  }

  setMuted(muted: boolean) {
    if (muted) {
      this.#player.mute();
    } else {
      this.#player.unMute();
    }
  }

  seek(seconds: number) {
    this.#player.seekTo(seconds, true);
  }

  play() {
    this.#player.playVideo();
  }

  pause() {
    this.#player.pauseVideo();
  }
}
