# replay-repeat

Replay part of a video until you know it.
Open it at https://replay-repeat.nullvoxpopuli.com.
Load a YouTube link or a video file from your disk. You can drop a video file anywhere on the page.

| key                | action                           |
| :----------------- | :------------------------------- |
| `1` to `9`         | go back that many seconds        |
| `0`                | go back 10 seconds               |
| `[` and `]`        | set the loop start or end to now |
| `L`                | loop on or off                   |
| `R`                | go to the loop start             |
| `K`                | play or pause                    |
| `<` and `>`        | slower or faster                 |
| `M`                | mute or unmute                   |
| `T`                | theatre mode on or off           |
| `F`                | full screen on or off            |
| `Ctrl`+`Z`         | undo a marker move               |
| `Ctrl`+`Shift`+`Z` | redo a marker move               |

Drag the two loop markers under the video to pick the part that loops.
When the loop is on, going back stops at the loop start.

## Links

The URL holds the video, the loop, and the speed, so a link opens the same replay.
For example: `/?youtube_video_id=dQw4w9WgXcQ&loop_start=30&loop_end=35.5&loop=1&speed=0.75`

| param              | value                                 |
| :----------------- | :------------------------------------ |
| `youtube_video_id` | the id of a YouTube video             |
| `loop_start`       | seconds, default `0`                  |
| `loop_end`         | seconds, default the end of the video |
| `loop`             | `1` when the loop is on               |
| `speed`            | `0.25` to `2`, default `1`            |

A file from your disk cannot be in a link, so a file uses only the last four.

There is no server:

- A video file stays on your disk, and the browser plays it from there.
- For YouTube links, the app loads the YouTube IFrame Player API.

This is an Ember app, created with [ember.nvp](https://github.com/NullVoxPopuli/ember.nvp), with [nvp.ui](https://github.com/NullVoxPopuli/nvp.ui) for the UI.

## Getting Started

### Prerequisites

- Node.js >= 24
- pnpm

### Installation

```sh
pnpm install
```

### Development

To start the local development server:

```sh
pnpm dev
```

### Production build

To build the app, then serve the build on `$PORT` (default 4200):

```sh
pnpm build
pnpm preview
```

## Features & Tooling

### GitHub Actions

Continuous Integration (CI) is configured under `.github/workflows/ci.yml` for automated testing and linting.

### Prettier

Code formatting is managed with [Prettier](https://prettier.io/).

- `pnpm format` - Format code
- `pnpm lint:prettier` - Check code formatting

### TypeScript

This project uses TypeScript 7 and [ember-content-mapper](https://github.com/NullVoxPopuli/ember-content-mapper) for static type checking.

- `pnpm lint:types` - Typecheck code with TypeScript
- Imports of `.gts` and `.gjs` modules must include the extension
- Editor setup: see [ember-content-mapper's editors section](https://github.com/NullVoxPopuli/ember-content-mapper#editors)
