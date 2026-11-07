import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";

import { DocumentFileDrop } from "ember-primitives/components/file-drop";
import { Shell } from "nvp.ui";

import { Replay } from "#components/replay.gts";
import { SourcePicker } from "#components/source-picker.gts";
import { HandoutSavedLinks } from "#components/handout-saved.gts";
import { NEW_VIDEO, PARAMS } from "#utils/params.ts";
import { fileSource, isMedia } from "#utils/source.ts";
import { youTubeIdOf } from "#utils/youtube.ts";

import type UrlStateService from "#services/url-state.ts";
import type { Source } from "#utils/source.ts";

interface Signature {
  Args: {
    buildVersion: string;
  };
}

export class HandoutPage extends Component<Signature> {
  @service("url-state") declare urlState: UrlStateService;

  @tracked file: { key: string; source: Source } | undefined;
  @tracked dropError: string | undefined;

  get sources() {
    const param = this.urlState.param(PARAMS.youtube);
    const id = param ? youTubeIdOf(param) : undefined;

    if (id) return [{ key: "youtube:" + id, source: { kind: "youtube" as const, id } }];
    if (this.file) return [this.file];

    return [];
  }

  get currentSource() {
    return this.sources[0]?.source;
  }

  load = (source: Source) => {
    this.dropError = undefined;

    if (source.kind === "drive") return;

    if (source.kind === "youtube") {
      this.file = undefined;
      this.urlState.update({
        ...NEW_VIDEO,
        [PARAMS.youtube]: source.id,
        [PARAMS.drive]: null,
        [PARAMS.driveDownload]: null,
      });

      return;
    }

    this.file = { key: crypto.randomUUID(), source };
    this.urlState.update({
      ...NEW_VIDEO,
      [PARAMS.youtube]: null,
      [PARAMS.drive]: null,
      [PARAMS.driveDownload]: null,
    });
  };

  loadFiles = (files: File[]) => {
    const file = files[0];

    if (file && !isMedia(file)) {
      this.dropError = file.name + " is not a video or audio file.";

      return;
    }

    const source = fileSource(files);

    if (source) this.load(source);
  };

  useDriveLocal = (file: File) => this.load({ kind: "file", file });

  <template>
    <Shell>
      <DocumentFileDrop @onFiles={{this.loadFiles}} as |page|>
        {{#if page.isDragging}}
          <div class="page-drop" data-test-page-drop>Drop to load the video</div>
        {{/if}}
      </DocumentFileDrop>

      <div class="layout">
        <header class="layout__header">
          <div class="layout__title">
            <h1>Replay, repeat</h1>
            <span class="layout__build">Version {{@buildVersion}}</span>
          </div>
        </header>

        <main>
          <p class="handout__intro">
            Load YouTube or local videos. Saved entries and local video copies stay in this browser
            and are never uploaded. Browser storage can fill or be cleared; exported lists do not
            contain video files.
          </p>

          <SourcePicker @onSource={{this.load}} />

          {{#if this.dropError}}
            <p class="replay__error" role="alert">{{this.dropError}}</p>
          {{/if}}

          <HandoutSavedLinks @source={{this.currentSource}} @onLoad={{this.load}} />

          {{#each this.sources key="key" as |item|}}
            <Replay @source={{item.source}} @onUseLocal={{this.useDriveLocal}} />
          {{else}}
            <p class="handout__empty">Choose a video above to start replaying.</p>
          {{/each}}
        </main>
      </div>
    </Shell>
  </template>
}