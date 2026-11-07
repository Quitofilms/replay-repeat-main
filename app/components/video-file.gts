import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { waitForPromise } from "@ember/test-waiters";

import { modifier } from "ember-modifier";

import { FilePlayer, type Player } from "#utils/player.ts";

interface Signature {
  Args: {
    file: File;
    onReady: (player: Player) => void;
  };
}

export class VideoFile extends Component<Signature> {
  /**
   * The file stays on the disk. The browser reads it through this URL.
   */
  url = URL.createObjectURL(this.args.file);

  @tracked error: string | undefined;

  willDestroy() {
    super.willDestroy();
    URL.revokeObjectURL(this.url);
  }

  attach = modifier((video: HTMLVideoElement) => {
    const loaded = new Promise<void>((resolve) => {
      const onLoaded = () => {
        this.args.onReady(new FilePlayer(video));
        resolve();
      };
      const onError = () => {
        this.error = `This browser cannot play ${this.args.file.name}.`;
        resolve();
      };

      video.addEventListener("loadedmetadata", onLoaded, { once: true });
      video.addEventListener("error", onError, { once: true });
    });

    void waitForPromise(loaded);
  });

  <template>
    {{#if this.error}}
      <p class="replay__error" role="alert">{{this.error}}</p>
    {{else}}
      <video
        class="replay__media"
        src={{this.url}}
        playsinline
        preload="auto"
        aria-label={{@file.name}}
        {{this.attach}}
      ></video>
    {{/if}}
  </template>
}
