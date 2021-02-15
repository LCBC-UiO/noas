importScripts("./blob-stream.js");
importScripts("./pdfkit.standalone.js");

function createPdf(m) {
console.log("createPdf");
  var doc = new PDFDocument();
  const stream = doc.pipe(blobStream());

  // header
  doc
    .fontSize(24).font('Helvetica').text('NOAS data documentation', {align: 'center'})
  doc
    .fontSize(12).text(`Version: ${m.version.label} (${m.version.ts})`, {align: 'center'})
    .fontSize(12).text(`Project: ${m.project}`, {align: 'center'})
  doc.moveDown();
  // tables
  m.tables.forEach(et => {
    if (et.n == 0) {
      return;
    }
    doc.moveDown();
    doc.fontSize(16);
    doc
      //.font('Helvetica-Oblique').text("Table: ", {continued: true})
      .font('Helvetica-Bold').text(`${et.title}`, {continued: true, underline: true})
      .font("Helvetica").text(` (${et.id})`);
    doc.fontSize(12);
    if (et.category) {
      doc.font('Helvetica-Oblique').text('category: ', {continued: true, indent: 10}).font('Helvetica').text(et.category);
    }
    doc.font('Helvetica-Oblique').text('type: ', {continued: true, indent: 10}).font('Helvetica').text(et.sampletype);
    doc.font('Helvetica-Oblique').text('num. rows: ', {continued: true, indent: 10}).font('Helvetica').text(et.n);
    if (et.descr) {
      doc.moveDown();
      doc
        .font('Helvetica').text('Description: ', {continued: true, indent: 0})
        .font('Helvetica').text(et.descr);
    }
    // columns
    et.columns.forEach(ec => {
      doc.moveDown();
      doc.font('Helvetica-Bold').text(ec.title, {continued: ec.descr!=null});
      if (ec.descr) {
        doc.font('Helvetica').text(" - ", {continued: true}).text(ec.descr);
      }
      doc
        .font('Helvetica-Oblique').text('ID: ', {continued: true, indent: 10})
        .font('Helvetica').text(et.id == "core" ? ec.id : `${et.id}_${ec.id}`);
      if (ec.type) {
        doc
          .font('Helvetica-Oblique').text('type: ', {continued: true, indent: 10})
          .font('Helvetica').text(ec.type);
      }
    });
  });
  doc.end();
  stream.on('finish', function() {
    postMessage({ type: 'done', value: this.toBlobURL("application/pdf")})
  });
}

onmessage = function(msg) {
  if (msg.data.type == "init") {
    createPdf(msg.data.value.metadata);
  }
};

