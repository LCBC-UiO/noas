importScripts("./blob-stream.js");
importScripts("./pdfkit.standalone.js");

// we use it twice, first temp render to get an index for the TOC, then again
function _writeTables(doc, m, onpageadd) {
  let toc = [];
  let current_page = 1;
  doc.on('pageAdded', () => {
    onpageadd(current_page);
    current_page++;
  });
  // tables
  m.tables.forEach(et => {
    if (et.n == 0) {
      return;
    }
    toc.push({ table: et, page: current_page });
    doc.moveDown();
    doc.fontSize(16);
    doc.lineGap(0);
    doc
      //.font('Helvetica-Oblique').text("Table: ", {continued: true})
      .font('Helvetica-Bold').text(`${et.title}`, {continued: true, underline: true})
      .font("Helvetica").text(` (${et.id})`);
    doc.fontSize(12);
    if (et.category.length) {
      doc.font('Helvetica-Oblique').text('category: ', {continued: true, indent: 10}).font('Helvetica').text(et.category.join(", "));
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
      if (ec.id == "noas_data_source") {
        return;
      }
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
  return toc;
}

function _create_pdf(m) {
  // crate TOC index from temp doc
  const toc = (function(){
    var doc = new PDFDocument({
      size: "A4",
    });
    const stream = doc.pipe(blobStream());
    return _writeTables(doc, m, (_)=>{});
  })();
  // init final doc
  var doc = new PDFDocument({
    size: "A4",
    bufferPages: true,
  });
  const stream = doc.pipe(blobStream());
  // write header
  doc
    .fontSize(24).font('Helvetica').text('NOAS data documentation', {align: 'center'})
  doc
    .fontSize(12).text(`Version: ${m.version.label} (${m.version.ts})`, {align: 'center'})
    .fontSize(12).text(`Project: ${m.project}`, {align: 'center'})
  // write TOC
  {
    doc.moveDown();
    doc.moveDown();
    doc
    .fontSize(14).font('Helvetica').text('Table of Contents', {align: 'left'});
    doc.moveDown();
    let curr_cat = -1; // something we don't expect to be real data (core has cat null)
    toc.forEach(e => {
      const get_out_cat = (et) => {
        if (et.idx == 0) return "Core data";
        if (et.category.length == 0) return "uncategorized";
        return et.category.join(", ");
      };
      doc.lineGap(4);
      if (curr_cat != get_out_cat(e.table)) {
        const out_cat = get_out_cat(e.table);
        doc
          .fontSize(11).font('Helvetica').text(out_cat, {align: 'left', underline: true , indent: 20});
      }
      doc
        .fontSize(10)
        .font('Helvetica').text(`${e.table.title} (${e.table.id})`, {continued: true, indent: 40})
        .font('Helvetica-Oblique').text(`    ${e.page}`);
        curr_cat = get_out_cat(e.table);
    });
  }
  // get current page - to be used add offset for page numbers
  const page_offset = (function() {
    const range = doc.bufferedPageRange();
    return range.start + range.count;
  })();
  // write tables
  doc.addPage();
  _writeTables(doc, m, (_)=>{});
  // write page numbers
  const range = doc.bufferedPageRange(); 
  for (let i = page_offset; i < range.count; i++) {
    doc.switchToPage(i);
    doc.text(i-page_offset+1, 550, 810);
  }
  // finish
  doc.end();
  stream.on('finish', function() {
    postMessage({ type: 'done', value: this.toBlobURL("application/pdf")});
  });
}

// worker
onmessage = function(msg) {
  if (msg.data.type == "init") {
    _create_pdf(msg.data.value.metadata);
  }
};
