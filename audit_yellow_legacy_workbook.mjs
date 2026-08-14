import fs from "node:fs/promises";
import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "C:/Users/invok/AppData/Roaming/pokemon-love2d/mods/yellow_legacy_changes/Yellow-Legacy-Rival-Teams-with-Starters.xlsx";
const outputDir = "C:/Users/invok/OneDrive/Documents/ChatGPT/Gen1 Recomp Mods/.audit/yellow_legacy_workbook";

await fs.mkdir(outputDir, { recursive: true });
const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);

const sheets = await workbook.inspect({
  kind: "sheet",
  include: "id,name",
  maxChars: 8000,
});
console.log("SHEETS");
console.log(sheets.ndjson);

const summary = await workbook.inspect({
  kind: "workbook,sheet,table",
  maxChars: 24000,
  tableMaxRows: 16,
  tableMaxCols: 16,
  tableMaxCellChars: 120,
});
console.log("SUMMARY");
console.log(summary.ndjson);

for (const name of [
  "Overview",
  "Jolteon Bulbasaur",
  "Flareon Charmander",
  "Vaporeon Squirtle",
]) {
  const region = await workbook.inspect({
    kind: "region",
    sheetId: name,
    range: "A1:Z80",
    maxChars: 16000,
  });
  console.log(`REGION ${name}`);
  console.log(region.ndjson);

  const preview = await workbook.render({
    sheetName: name,
    autoCrop: "all",
    scale: 1,
    format: "png",
  });
  const safeName = name.toLowerCase().replaceAll(" ", "_");
  await fs.writeFile(
    `${outputDir}/${safeName}.png`,
    new Uint8Array(await preview.arrayBuffer()),
  );
}
