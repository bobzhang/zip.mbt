#!/usr/bin/env node
// Generate expected CRCs for deterministic pseudo-random byte sequences
// using reflected polynomial 0xEDB88320.

const poly = 0xedb88320 >>> 0;
function makeTable() {
  const t = new Uint32Array(256);
  for (let i = 0; i < 256; i++) {
    let c = i;
    for (let k = 0; k < 8; k++) c = c & 1 ? poly ^ (c >>> 1) : c >>> 1;
    t[i] = c >>> 0;
  }
  return t;
}
const T0 = makeTable();
function crc32(bytes) {
  let c = 0xffffffff >>> 0;
  for (let i = 0; i < bytes.length; i++)
    c = (c >>> 8) ^ T0[(c ^ bytes[i]) & 0xff];
  return (c ^ 0xffffffff) >>> 0;
}
let state = 0x12345678 >>> 0;
function nextByte() {
  state = (Math.imul(state, 1664525) + 1013904223) >>> 0; // LCG
  return state >>> 24; // high byte
}
const lengths = [
  0, 1, 2, 3, 4, 5, 7, 8, 9, 15, 16, 17, 31, 32, 33, 63, 64, 65, 127, 128, 129,
  255, 256, 257, 511, 512, 513, 1024, 1536, 2048, 3072, 4096,
];
const crcs = [];
for (const len of lengths) {
  const arr = new Uint8Array(len);
  for (let i = 0; i < len; i++) arr[i] = nextByte();
  crcs.push(crc32(arr));
}
console.log(JSON.stringify({ lengths, crcs }, null, 2));
