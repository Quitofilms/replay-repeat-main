import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import type Owner from "@ember/owner";
import { on } from "@ember/modifier";

import { Button } from "nvp.ui";

import { MEDIA_FILES, isMedia } from "#utils/source.ts";
import {
  getSavedLinks,
  getSavedVideo,
  importLinks,
  isSavedLink,
  removeLink,
  saveLink,
} from "#utils/handout-storage.ts";

import type { SavedLink } from "#utils/handout-storage.ts";
import type { Source } from "#utils/source.ts";

interface Signature {
  Args: {
    source?: Source;
    onLoad: (source: Source) => void;
  };
}

type LinkFilter = "all" | "youtube" | "local";

export class HandoutSavedLinks extends Component<Signature> {
  @tracked links: SavedLink[] = [];
  @tracked filter: LinkFilter = "all";
  @tracked status = "";
  accept = MEDIA_FILES;

  constructor(owner: Owner, args: Signature["Args"]) {
    super(owner, args);
    void this.refresh();
  }

  get sourceTitle() {
    const source = this.args.source;

    if (!source || source.kind === "drive") return "";

    return source.kind === "file" ? source.file.name : source.id;
  }

  get visibleLinks() {
    return this.filter === "all"
      ? this.links
      : this.links.filter((link) => link.kind === this.filter);
  }

  async refresh() {
    try {
      this.links = await getSavedLinks();
    } catch (error) {
      this.status = error instanceof Error ? error.message : "Could not load saved links.";
    }
  }

  saveCurrent = async (event: SubmitEvent) => {
    event.preventDefault();

    const source = this.args.source;
    if (!source || source.kind === "drive") return;

    const form = event.currentTarget as HTMLFormElement;
    const data = new FormData(form);
    const title = String(data.get("title") ?? "").trim();
    const note = String(data.get("note") ?? "").trim();

    if (!title) {
      this.status = "Add a title before saving.";

      return;
    }

    const id = crypto.randomUUID();
    const savedAt = Date.now();

    try {
      if (source.kind === "youtube") {
        await saveLink({ id, kind: "youtube", videoId: source.id, title, note, savedAt });
      } else {
        const link: SavedLink = {
          id,
          kind: "local",
          fileId: id,
          fileName: source.file.name,
          fileType: source.file.type,
          title,
          note,
          savedAt,
        };
        await saveLink(link, source.file);
      }

      this.status = "Saved in this browser.";
      form.reset();
      await this.refresh();
    } catch (error) {
      this.status =
        error instanceof Error
          ? error.message
          : "Could not save this item. The browser may be out of storage space.";
    }
  };

  loadLink = async (link: SavedLink) => {
    if (link.kind === "youtube") {
      this.args.onLoad({ kind: "youtube", id: link.videoId });

      return;
    }

    try {
      const file = await getSavedVideo(link.fileId);

      if (!file) {
        this.status = "This list entry has no video stored here. Choose the video file below.";

        return;
      }

      this.args.onLoad({ kind: "file", file });
      this.status = "";
    } catch (error) {
      this.status = error instanceof Error ? error.message : "Could not open this saved video.";
    }
  };

  attachFile = async (link: SavedLink, event: Event) => {
    if (link.kind !== "local") return;

    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    input.value = "";

    if (!file) return;
    if (!isMedia(file)) {
      this.status = "Choose a video or audio file.";

      return;
    }

    try {
      await saveLink({ ...link, fileName: file.name, fileType: file.type }, file);
      this.status = "Video copied into this browser's storage.";
      await this.refresh();
    } catch (error) {
      this.status =
        error instanceof Error
          ? error.message
          : "Could not store this video. It may be too large for this browser.";
    }
  };

  remove = async (link: SavedLink) => {
    try {
      await removeLink(link);
      this.status = "Removed from this browser.";
      await this.refresh();
    } catch (error) {
      this.status = error instanceof Error ? error.message : "Could not remove this item.";
    }
  };

  changeFilter = (event: Event) => {
    this.filter = (event.currentTarget as HTMLSelectElement).value as LinkFilter;
  };

  exportList = () => {
    const file = new Blob(
      [JSON.stringify({ format: "replay-repeat-links", version: 1, entries: this.links }, null, 2)],
      { type: "application/json" },
    );
    const url = URL.createObjectURL(file);
    const anchor = document.createElement("a");

    anchor.href = url;
    anchor.download = "replay-repeat-links.json";
    anchor.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    this.status = "Exported the saved entries. Video files are not included.";
  };

  importList = async (event: Event) => {
    const input = event.currentTarget as HTMLInputElement;
    const file = input.files?.[0];
    input.value = "";

    if (!file) return;

    try {
      const data: unknown = JSON.parse(await file.text());
      const entries =
        data && typeof data === "object" && "entries" in data && Array.isArray(data.entries)
          ? data.entries.filter(isSavedLink)
          : [];

      if (entries.length === 0) {
        this.status = "That file has no saved entries in a supported format.";

        return;
      }

      await importLinks(entries);
      this.status =
        "Imported " +
        entries.length +
        (entries.length === 1 ? " saved entry. " : " saved entries. ") +
        "Local video files must be chosen on this device.";
      await this.refresh();
    } catch (error) {
      this.status = error instanceof Error ? error.message : "Could not import that list.";
    }
  };

  <template>
    <section class="handout__library" aria-labelledby="handout-library-title">
      <div class="handout__library-heading">
        <h2 id="handout-library-title">Saved on this device</h2>
        <div class="handout__library-actions">
          <Button @onClick={{this.exportList}} @disabled={{unless this.links.length "No saved links"}}>Export list</Button>
          <label class="handout__import">
            Import list
            <input type="file" accept=".json,application/json" {{on "change" this.importList}} />
          </label>
        </div>
      </div>

      {{#if @source}}
        <form class="handout__save-form" {{on "submit" this.saveCurrent}}>
          <label>
            Title
            <input
              name="title"
              required
              value={{this.sourceTitle}}
              aria-label="Title for saved link"
            />
          </label>
          <label>
            Note (optional)
            <textarea name="note" rows="2" aria-label="Note for saved link"></textarea>
          </label>
          <Button @variant="primary" type="submit">Save to this device</Button>
        </form>
      {{/if}}

      <div class="handout__filter">
        <label>
          Show
          <select aria-label="Filter saved links" {{on "change" this.changeFilter}}>
            <option value="all">YouTube and local</option>
            <option value="youtube">YouTube</option>
            <option value="local">Local files</option>
          </select>
        </label>
      </div>

      {{#if this.links.length}}
        <div class="saved__list">
          {{#each this.visibleLinks key="id" as |link|}}
            <article class="saved__item">
              <div>
                <strong>{{link.title}}</strong>
                <span class="handout__kind">{{if (eq link.kind "youtube") "YouTube" "Local file"}}</span>
                {{#if link.note}}<p>{{link.note}}</p>{{/if}}
                {{#if (eq link.kind "local")}}
                  <small>{{link.fileName}} · Stored in this browser; exports include the entry, not the video.</small>
                {{/if}}
              </div>
              <Button @onClick={{fn this.loadLink link}}>Load</Button>
              {{#if (eq link.kind "local")}}
                <label class="handout__choose-file">
                  Choose or replace file
                  <input
                    type="file"
                    accept={{this.accept}}
                    {{on "change" (fn this.attachFile link)}}
                  />
                </label>
              {{/if}}
              <Button @variant="bare" @onClick={{fn this.remove link}}>Remove</Button>
            </article>
          {{else}}
            <p>No saved entries in this filter.</p>
          {{/each}}
        </div>
      {{else}}
        <p class="handout__empty">No saved entries yet.</p>
      {{/if}}

      <p class="handout__status" role="status">{{this.status}}</p>
    </section>
  </template>
}