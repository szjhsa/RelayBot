import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const here = dirname(fileURLToPath(import.meta.url));
const sourcePath = resolve(here, "..", "..", "relay_v1.txt");
const raw = await readFile(sourcePath, "utf8");
const source = raw.replace(/^\uFEFF/, "");
const mod = await import(
    "data:text/javascript;base64," + Buffer.from(source, "utf8").toString("base64")
);

assert.ok(mod && typeof mod.verifyTextWithCode === "function", "verifyTextWithCode must be exported");
assert.ok(mod.UI_TEXT && typeof mod.UI_TEXT.VERIFY_PROMPT === "function", "UI_TEXT must be exported");

const { UI_TEXT, verifyTextWithCode } = mod;
const codes = ["Ab3$z9", "xY_7!q", "Kp2&w5", "M4n-s8"];

for (const code of codes) {
    for (const text of [UI_TEXT.VERIFY_PROMPT(code), UI_TEXT.VERIFY_WRONG(code)]) {
        const msg = verifyTextWithCode(text, code);
        assert.equal(msg.text, text, "helper must keep the original text");
        assert.equal(msg.entities.length, 1, "helper must produce exactly one entity");
        assert.equal(msg.entities[0].type, "code", "entity type must be code");
        assert.equal(msg.entities[0].length, code.length, "entity length must equal code length");
        assert.ok(msg.entities[0].offset >= 0, "entity offset must be valid");
        const actual = msg.text.slice(
            msg.entities[0].offset,
            msg.entities[0].offset + msg.entities[0].length
        );
        assert.equal(actual, code, "entity offset must point exactly at the verification code");
    }
}

assert.throws(
    () => verifyTextWithCode("这条消息里没有验证码", "Ab3$z9"),
    /验证码实体定位失败/,
    "helper must fail loudly when the code cannot be located"
);

console.log("RelayBot v1 verify entity test passed.");
