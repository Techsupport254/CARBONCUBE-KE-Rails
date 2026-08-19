const fs = require('fs');
const path = require('path');

// Resolve sharp from frontend or backend node_modules
let sharp;
try {
  sharp = require('sharp');
} catch (e) {
  try {
    const frontendPath = path.resolve(__dirname, '../../../frontend/node_modules/sharp');
    sharp = require(frontendPath);
  } catch (err) {
    console.error('Failed to load sharp:', err);
    process.exit(1);
  }
}

const inputSvgPath = process.argv[2];
const outputPngPath = process.argv[3];

if (!inputSvgPath || !outputPngPath) {
  console.error('Usage: node render_qr_standee.cjs <input_svg_path> <output_png_path>');
  process.exit(1);
}

try {
  const svgBuffer = fs.readFileSync(inputSvgPath);
  sharp(svgBuffer, { density: 300 })
    .png({ quality: 100 })
    .toFile(outputPngPath)
    .then(() => {
      console.log('RENDER_SUCCESS');
      process.exit(0);
    })
    .catch((err) => {
      console.error('Render error:', err);
      process.exit(1);
    });
} catch (err) {
  console.error('File read error:', err);
  process.exit(1);
}
