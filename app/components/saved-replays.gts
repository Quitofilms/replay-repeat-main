import Component from '@glimmer/component';
import type Owner from '@ember/owner';
import { tracked } from '@glimmer/tracking';
import { on } from '@ember/modifier';

import { prepareDrive, removeSharedSavedReplay, saveSharedSavedReplays, uploadToDrive } from '#utils/drive.ts';

import type { Source } from '#utils/source.ts';

interface SavedReplay {
  id: string;
  title: string;
  note: string;
  url: string;
  savedAt: string;
}

interface Signature {
  Args: {
    source?: Source;
    url: string;
    title?: string;
    note?: string;
    onUploaded: (id: string, title: string, note: string, downloadUrl: string) => void;
  };
}

const STORAGE_KEY = 'replay-repeat:saved-videos:v1';

function initialTitle(source?: Source): string {
  if (!source) return '';
  if (source.kind === 'file') return source.file.name.replace(/\.[^.]+$/, '');
  if (source.kind === 'drive') return 'Saved video';
  return source.id;
}

function replayUrl(
  current: string,
  title: string,
  note: string,
  driveId?: string,
  downloadUrl?: string,
): string {
  const url = new URL(current);
  url.searchParams.delete('saved_title');
  url.searchParams.delete('saved_note');
  if (driveId) {
    url.searchParams.delete('youtube_video_id');
    url.searchParams.set('drive_file_id', driveId);
    if (downloadUrl) url.searchParams.set('drive_download_url', downloadUrl);
  }
  url.searchParams.set('saved_title', title.trim());
  if (note.trim()) url.searchParams.set('saved_note', note.trim());
  return url.toString();
}

export class SavedReplays extends Component<Signature> {
  @tracked title: string;
  @tracked note: string;
  @tracked items: SavedReplay[] = [];
  @tracked busy = false;
  @tracked syncing = false;
  @tracked error: string | undefined;
  @tracked copied = false;

  constructor(owner: Owner, args: Signature['Args']) {
    super(owner, args);
    this.title = args.title || initialTitle(args.source);
    this.note = args.note || '';
    try {
      const saved = localStorage.getItem(STORAGE_KEY);
      this.items = saved ? JSON.parse(saved) as SavedReplay[] : [];
    } catch {
      this.items = [];
    }
    prepareDrive();
  }

  get localFile() {
    return this.args.source?.kind === 'file' ? this.args.source.file : undefined;
  }

  updateTitle = (event: Event) => {
    this.title = (event.currentTarget as HTMLInputElement).value;
  };

  updateNote = (event: Event) => {
    this.note = (event.currentTarget as HTMLTextAreaElement).value;
  };

  save = async (event: SubmitEvent) => {
    event.preventDefault();
    const title = this.title.trim();
    if (!this.args.source) {
      this.error = 'Load a video before saving a replay.';
      return;
    }
    if (!title) {
      this.error = 'Add a title before saving.';
      return;
    }
    const item: SavedReplay = {
      id: crypto.randomUUID(), title, note: this.note.trim(),
      url: replayUrl(this.args.url, title, this.note), savedAt: new Date().toISOString(),
    };
    this.add(item);
    await this.syncShared();
  };

  uploadAndSave = async () => {
    const file = this.localFile;
    const title = this.title.trim();
    if (!file || !title) {
      this.error = title ? 'Choose a local video first.' : 'Add a title before saving.';
      return;
    }
    this.busy = true;
    this.error = undefined;
    try {
      const { id: driveId, downloadUrl, token } = await uploadToDrive(file, title, this.note);
      const item: SavedReplay = {
        id: crypto.randomUUID(), title, note: this.note.trim(),
        url: replayUrl(this.args.url, title, this.note, driveId, downloadUrl), savedAt: new Date().toISOString(),
      };
      this.add(item);
      this.args.onUploaded(driveId, title, this.note.trim(), downloadUrl);
      this.items = await saveSharedSavedReplays(this.items, token);
      this.persist();
    } catch (error) {
      this.error = error instanceof Error ? error.message : String(error);
    } finally {
      this.busy = false;
    }
  };

  syncShared = async () => {
    this.syncing = true;
    this.error = undefined;
    try {
      this.items = await saveSharedSavedReplays(this.items);
      this.persist();
    } catch (error) {
      this.error = `Saved on this device, but could not sync the shared list: ${error instanceof Error ? error.message : String(error)}`;
    } finally {
      this.syncing = false;
    }
  };

  add(item: SavedReplay) {
    this.items = [item, ...this.items];
    this.error = undefined;
    this.persist();
  }

  remove = async (id: string) => {
    this.items = this.items.filter((item) => item.id !== id);
    this.persist();
    try {
      await removeSharedSavedReplay(id);
    } catch (error) {
      this.error = `Removed on this device, but could not remove it from the shared list: ${error instanceof Error ? error.message : String(error)}`;
    }
  };

  persist() {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(this.items));
    } catch {
      this.error = 'This browser could not save the replay list. Check its available storage.';
    }
  }

  copy = async (url: string) => {
    try {
      await navigator.clipboard.writeText(url);
      this.copied = true;
      setTimeout(() => this.copied = false, 1800);
    } catch {
      this.error = 'Could not copy the link. Open the saved replay and copy its address.';
    }
  };

  <template>
    <section class='saved' aria-label='Saved replays' data-test-saved>
      <details open={{not @source}}>
        <summary>{{if @source 'Save and share this replay' 'Saved replays'}}</summary>
        {{#if @source}}
        <form class='saved__form' {{on 'submit' this.save}}>
          <label class='source__field'>
            <span>Title</span>
            <input value={{this.title}} required maxlength='160' {{on 'input' this.updateTitle}} />
          </label>
          <label class='source__field'>
            <span>Why did you save it? <span class='saved__optional'>(optional)</span></span>
            <textarea value={{this.note}} maxlength='1000' rows='2' {{on 'input' this.updateNote}}></textarea>
          </label>
          {{#if this.localFile}}
            <button type='button' disabled={{this.busy}} {{on 'click' this.uploadAndSave}} data-test-upload-save>
              {{if this.busy 'Uploading to Drive…' 'Upload to Drive and save'}}
            </button>
            <p class='saved__hint'>The video will be shared with anyone who has its link.</p>
          {{else}}
            <button type='submit' data-test-save>Save replay</button>
          {{/if}}
        </form>
        {{/if}}
        {{#if this.error}}<p class='replay__error' role='alert'>{{this.error}}</p>{{/if}}
        <button type='button' disabled={{this.syncing}} {{on 'click' this.syncShared}} data-test-load-shared-list>
          {{if this.syncing 'Loading shared list…' 'Load shared list'}}
        </button>
        <p class='saved__hint'>Shared replays are stored in the Repeat Replay Drive folder. Connect to Google on each device to load and merge the list.</p>
      </details>

      {{#if this.items.length}}
        <div class='saved__list'>
          <h2>Saved replays</h2>
          {{#each this.items as |item|}}
            <article class='saved__item'>
              <div><a href={{item.url}}>{{item.title}}</a>{{#if item.note}}<p>{{item.note}}</p>{{/if}}</div>
              <button type='button' {{on 'click' (fn this.copy item.url)}}>Copy link</button>
              <button type='button' aria-label='Remove {{item.title}}' {{on 'click' (fn this.remove item.id)}}>Remove</button>
            </article>
          {{/each}}
          {{#if this.copied}}<p role='status'>Link copied.</p>{{/if}}
        </div>
      {{/if}}
    </section>
  </template>
}
