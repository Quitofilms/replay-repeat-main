import Component from '@glimmer/component';
import { tracked } from '@glimmer/tracking';
import { waitForPromise } from '@ember/test-waiters';

import { modifier } from 'ember-modifier';

import { driveViewUrl } from '#utils/drive.ts';
import { FilePlayer, type Player } from '#utils/player.ts';

interface Signature {
  Args: { id: string; downloadUrl?: string; onReady: (player: Player) => void };
}

export class DriveVideo extends Component<Signature> {
  @tracked error: string | undefined;

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
        <a href={{driveViewUrl @id}} target='_blank' rel='noreferrer'>Open this video in Google Drive</a>
      </div>
    {{else}}
      <video class='replay__media' src={{@downloadUrl}} playsinline preload='metadata' aria-label='Shared Drive video' {{this.attach}}></video>
    {{/if}}
  </template>
}
