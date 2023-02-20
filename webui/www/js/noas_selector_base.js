class NoasSelectorBase {
  constructor(dstId, dbmeta) {
    this.dstId = dstId;
    this.dbmeta = dbmeta;
    if (this.render === undefined) {
      throw new TypeError("Must override render()");
    }
    if (this.getSelection === undefined) {
      throw new TypeError("Must override getSelection()");
    }
    if (this.setSelection === undefined) {
      throw new TypeError("Must override setSelection()");
    }
    if (this.clearSelection === undefined) {
      throw new TypeError("Must override clearSelection()");
    }
  }
}
