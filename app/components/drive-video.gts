import Component from '@glimmer/component';
import { on } from '@ember/modifier';
import { tracked } from '@glimmer/tracking';
import { waitForPromise } from '@ember/test-waiters';

import { modifier } from 'ember-modifier';

import { MEDIA_FILES, isMedia } from '#utils/source.ts';
import { driveViewUrl } from '#utils/drive.ts';
import { FilePlayer, type Player } from '#utils/player.ts';

interface Signature {
  Args: { id: string; downloadUrl?: string; onReady: (player: Player) => void; onUseLocal: (file: File) => void };
}

export class DriveVideo extends Component<Signature> {
  @tracked error: string | undefined;

  chooseLocal = (event: Event) => {
    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    if (!file) return;
    if (!isMedia(file)) {
      this.error = "Choose a video or audio file.";
      return;
    }
    this.args.onUseLocal(file);
  };
  attach = modifier((video: HTMLVideoElement) => {
    const loaded = new Promise<void>((resolve) => {
      video.addEventListener('loadedmetadata', () => {
        this.args.onReady(new FilePlayer(video));
        resolve();
      }, { once: true });
      video.addEventListener('error', () => {
        this.error = 'This shared Drive video could not be played. Check that it is shared by link and uses a browser-supported format.';
        resolve();
      }, { once: true });
    });
    void waitForPromise(loaded);
  });

  <template>
    {{#if this.error}}
      <div class='replay__error' role='alert'>
        <p>{{this.error}}</p>
        <p>Download the video, then select the downloaded file to play it on this device.</p>
        <a href={{@downloadUrl}} download data-test-drive-download>Download video to this device</a>
        <label class='drive-video__pick'>
          Choose downloaded video
          <input type='file' accept={{MEDIA_FILES}} aria-label='Choose downloaded video' data-test-use-local {{on 'change' this.chooseLocal}} />
        </label>
        <a href={{driveViewUrl @id}} target='_blank' rel='noreferrer'>Open this video in Google Drive</a>
      </div>
    {{else}}
      <video class='replay__media' src={{@downloadUrl}} playsinline preload='metadata' aria-label='Shared Drive video' {{this.attach}}></video>
    {{/if}}
  </template>
}
