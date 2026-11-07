import type { TOC } from "@ember/component/template-only";

export const Shortcuts: TOC<object> = <template>
  <section class="shortcuts surface" aria-labelledby="shortcuts-title">
    <h2 id="shortcuts-title">Keys</h2>
    <dl>
      <div>
        <dt><kbd>1</kbd> to <kbd>9</kbd></dt>
        <dd>Go back that many seconds</dd>
      </div>
      <div>
        <dt><kbd>0</kbd></dt>
        <dd>Go back 10 seconds</dd>
      </div>
      <div>
        <dt><kbd>[</kbd> and <kbd>]</kbd></dt>
        <dd>Set the loop start or end to now</dd>
      </div>
      <div>
        <dt><kbd>L</kbd></dt>
        <dd>Loop on or off</dd>
      </div>
      <div>
        <dt><kbd>R</kbd></dt>
        <dd>Go to the loop start</dd>
      </div>
      <div>
        <dt><kbd>K</kbd></dt>
        <dd>Play or pause</dd>
      </div>
      <div>
        <dt><kbd>&lt;</kbd> and <kbd>&gt;</kbd></dt>
        <dd>Slower or faster</dd>
      </div>
      <div>
        <dt><kbd>M</kbd></dt>
        <dd>Mute or unmute</dd>
      </div>
      <div>
        <dt><kbd>T</kbd></dt>
        <dd>Theatre mode on or off (<kbd>Esc</kbd> leaves)</dd>
      </div>
      <div>
        <dt><kbd>F</kbd></dt>
        <dd>Full screen on or off, or double-click the video</dd>
      </div>
      <div>
        <dt><kbd>Ctrl</kbd> or <kbd>⌘</kbd> + <kbd>Z</kbd></dt>
        <dd>Undo a marker move</dd>
      </div>
      <div>
        <dt><kbd>Ctrl</kbd> or <kbd>⌘</kbd> + <kbd>Shift</kbd> + <kbd>Z</kbd></dt>
        <dd>Redo a marker move</dd>
      </div>
    </dl>
    <p>When the loop is on, going back stops at the loop start.</p>
  </section>
</template>;
