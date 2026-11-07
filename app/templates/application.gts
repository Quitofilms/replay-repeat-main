import "#app/styles.css";

import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";

import { DocumentFileDrop } from "ember-primitives/components/file-drop";
import { ExternalLink, Shell } from "nvp.ui";
import { ThemeToggle } from "nvp.ui/theme-toggle";

import { Replay } from "#components/replay.gts";
import { SavedReplays } from "#components/saved-replays.gts";
import { SourcePicker } from "#components/source-picker.gts";
import { Welcome } from "#components/welcome.gts";
import { NEW_VIDEO, PARAMS } from "#utils/params.ts";
import { fileSource, isMedia } from "#utils/source.ts";
import { youTubeIdOf } from "#utils/youtube.ts";
import { isDriveDownloadUrl } from "#utils/drive.ts";

import type UrlStateService from "#services/url-state.ts";
import type { Source } from "#utils/source.ts";

export default class Application extends Component {
  @service("url-state") declare urlState: UrlStateService;

  /**
   * A file cannot be in the URL, so it stays here.
   * The key makes each loaded file a new replay, also the same file twice.
   */
  @tracked file: { key: string; source: Source } | undefined;

  /**
   * Why the last drop did not load, so that a drop never fails without a word.
   */
  @tracked dropError: string | undefined;

  /**
   * A YouTube video in the URL wins over a Drive link or a local file.
   */
  get sources() {
    const param = this.urlState.param(PARAMS.youtube);
    const id = param ? youTubeIdOf(param) : undefined;

    if (id) {
      const source: Source = { kind: "youtube", id };

      return [{ key: `youtube:${id}`, source }];
    }

    const driveId = this.urlState.param(PARAMS.drive);

    if (driveId && /^[\w-]+$/.test(driveId)) {
      const downloadUrl = this.urlState.param(PARAMS.driveDownload);
      const source: Source = {
        kind: "drive",
        id: driveId,
        downloadUrl: isDriveDownloadUrl(downloadUrl) ? downloadUrl : undefined,
      };

      return [{ key: `drive:${driveId}`, source }];
    }

    if (this.file) return [this.file];

    return [];
  }

  get currentURL() {
    return window.location.href;
  }

  get savedTitle() {
    return this.urlState.param(PARAMS.title);
  }

  get savedNote() {
    return this.urlState.param(PARAMS.note);
  }

  load = (source: Source) => {
    this.dropError = undefined;

    if (source.kind === "youtube") {
      this.file = undefined;
      this.urlState.update({ ...NEW_VIDEO, [PARAMS.youtube]: source.id, [PARAMS.drive]: null });

      return;
    }

    this.file = { key: crypto.randomUUID(), source };
    this.urlState.update({ ...NEW_VIDEO, [PARAMS.youtube]: null, [PARAMS.drive]: null });
  };

  useDriveLocal = (file: File) => {
    this.file = { key: crypto.randomUUID(), source: { kind: "file", file } };
    this.urlState.update({
      [PARAMS.youtube]: null,
      [PARAMS.drive]: null,
      [PARAMS.driveDownload]: null,
    });
  };

  uploaded = (id: string, title: string, note: string, downloadUrl: string) => {
    this.file = undefined;
    this.urlState.update({
      [PARAMS.youtube]: null,
      [PARAMS.drive]: id,
      [PARAMS.driveDownload]: downloadUrl,
      [PARAMS.title]: title,
      [PARAMS.note]: note || null,
    });
  };

  /**
   * The page takes any file, so a file that is not media gets a message.
   */
  loadFiles = (files: File[]) => {
    const file = files[0];

    if (file && !isMedia(file)) {
      this.dropError = `${file.name} is not a video or audio file.`;

      return;
    }

    const source = fileSource(files);

    if (source) this.load(source);
  };

  <template>
    <Shell>
      <DocumentFileDrop @onFiles={{this.loadFiles}} as |page|>
        {{#if page.isDragging}}
          <div class="page-drop" data-test-page-drop>Drop to load the video</div>
        {{/if}}
      </DocumentFileDrop>

      <div class="layout">
        <header class="layout__header">
          <h1>Replay, repeat</h1>
          <div class="layout__header-end">
            <ExternalLink href="https://github.com/NullVoxPopuli/replay-repeat" data-test-github>
              GitHub
            </ExternalLink>
            <ThemeToggle />
          </div>
        </header>

        <main>
          <SourcePicker @onSource={{this.load}} />

          {{#if this.dropError}}
            <p class="replay__error" role="alert" data-test-drop-error>{{this.dropError}}</p>
          {{/if}}

          {{! A new key starts a new replay, with a fresh undo history. }}
          {{#each this.sources key="key" as |item|}}
            <SavedReplays
              @source={{item.source}}
              @url={{this.currentURL}}
              @title={{this.savedTitle}}
              @note={{this.savedNote}}
              @onUploaded={{this.uploaded}}
            />
            <Replay @source={{item.source}} @onUseLocal={{this.useDriveLocal}} />
          {{else}}
            <Welcome />
          {{/each}}
        </main>
      </div>
    </Shell>
  </template>
}
