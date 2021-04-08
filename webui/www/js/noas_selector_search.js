

class NoasSelectorSearch extends NoasSelectorBase {
  nssSelection = null;
  nssColumns = null;
  fuse = null;

  constructor(dstId, dbmeta) {
    super(dstId, dbmeta);
  }

  render() {
    // create base elements
    const frag = document.createDocumentFragment();
    const enss = document.createElement("div");
    enss.id = "nss";
    frag.appendChild(enss);
    ["nssResults", "nssTable", "nssColumns", "nssSelection"].forEach(inner_id => {
      const ecol = document.createElement("div");
      ecol.classList.add("nsscol");
      enss.appendChild(ecol);
      const einner = document.createElement("div");
      einner.id = inner_id;
      einner.classList.add("nsscolinner");
      ecol.appendChild(einner);
    });
    document.getElementById(this.dstId).replaceChildren(frag);
    {
      const ein = document.createElement("input");
      ein.id = "inpSearch";
      ein.classList.add("nsscolheader");
      ein.placeholder = "Search";
      document.getElementById("nssResults").parentNode.prepend(ein);
    }
    {
      const e = document.createElement("div");
      e.innerHTML = "Table";
      e.classList.add("nsscolheader");
      document.getElementById("nssTable").parentNode.prepend(e);
    }
    {
      const e = document.createElement("div");
      e.innerHTML = "Columns";
      e.classList.add("nsscolheader");
      document.getElementById("nssColumns").parentNode.prepend(e);
    }
    {
      const e = document.createElement("div");
      e.innerHTML = "Selected";
      e.classList.add("nsscolheader");
      document.getElementById("nssSelection").parentNode.prepend(e);
    }
    this.nssSelection = new NssSelection("nssSelection");
    this.nssColumns = new NssColumns("nssColumns", this.nssSelection);
    this.nssSelection.onRemove = () => { this.nssColumns.update(); };
    this.nssSelection.addCol("core", "subject_id", true);


    let search_data = [];
    this.dbmeta.tables.forEach(t => {
      if (t.n == 0) {
        return;
      }
      search_data.push(
        {
          table: t,
        }
      );
      t.columns.forEach(c => search_data.push({
        column: c,
        _table: t,
      }))
    });

    this.fuse = new Fuse(search_data, {
      includeScore: true,
      includeMatches: true,
      findAllMatches: true,
      shouldSort: true,
      useExtendedSearch: true,
      keys: SearchItems.searchKeys,
    });
  
    document.getElementById("inpSearch").oninput = (e) => doSearch(e, this);
  }

  getSelection(){

  }

  setSelection(){

  }
  
  clearSelection(){

  }

  showTable(table, colid) {
    let frag = document.createDocumentFragment();
    let dl = document.createElement("dl");
    frag.appendChild(dl);
    {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Name";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = table.title;
    }
    {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "ID";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = table.id;
    }
    {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "n";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = table.n;
    }
    {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Sample type";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = {
        core: "core",
        cross: "cross-sectional",
        long: "longitudinal",
        repeated: "repeated",
      }[table.sampletype];
    }
    if (table.descr) {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Description";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = table.descr;
    }
    document.getElementById("nssTable").replaceChildren(frag);
  
    this.nssColumns.setTable(table, colid);
  }
}

/*----------------------------------------------------------------------------*/

function createNsRow(textcenter, textright, onclick) {
  let erow = document.createElement("div");
  erow.classList.add("resrow");
  if (onclick === null) erow.classList.add("nssdisabled");
  let ecenter = document.createElement("div");
  ecenter.classList.add("resrowcenter");
  erow.appendChild(ecenter);
  ecenter.innerHTML = textcenter;
  let ecaret = document.createElement("div");
  ecaret.classList.add("resrowright");
  ecaret.innerHTML = textright;
  erow.appendChild(ecaret);
  erow.onclick = onclick;
  return erow;
}

/*----------------------------------------------------------------------------*/

function doSearch(e, nss) {
  console.log(e);
  const sres = nss.fuse.search(e.data);
  let frag = document.createDocumentFragment();
  const maxResults = 40;
  sres.slice(0, maxResults).forEach(r => {
    const rowonclick = () => nss.showTable(
      r.item.table  ? r.item.table : r.item._table, 
      r.item.column ? r.item.column.id : null
    );
    frag.appendChild(
      createNsRow(SearchItems.prettyPrintHit(r), ">", rowonclick)
    );
  });
  document.getElementById("nssResults").innerHTML = '';
  document.getElementById("nssResults").appendChild(frag);
}

/*----------------------------------------------------------------------------*/

class NssSelection {
  onRemove = null;
  selCols = {};

  constructor(dstId, dbmeta) {
    this.distId = dstId;
  }
  set onRemove(onRemove) { this.onRemove = onRemove; }
  setSelection(sel_cols) {
    // this.selCols = sel_cols;
    let frag = document.createDocumentFragment();
  }
  getSelection() {
    return Object.keys(this.selCols).map(k => this.selCols[k]);
  }
  addCol(tableId, colId, disabled = false) {
    this.selCols[`${tableId}_${colId}`] = {
      table_id: tableId,
      column_id: colId,
      disabled: disabled,
    };
    this.render();
  }
  removeCol(tableId, colId) {
    delete this.selCols[`${tableId}_${colId}`];
    this.render();
    this.onRemove();
  }
  render() {
    let edst = document.getElementById(this.distId);
    const keys = Object.keys(this.selCols);
    edst.parentElement.firstElementChild.innerHTML = `Selections (${keys.length})`;
    console.log(edst.parentElement);
    let frag = document.createDocumentFragment();
    keys.forEach(k => {
      const c = this.selCols[k];
      const onRowClick = () => {
        this.removeCol(c.table_id, c.column_id);
      };
      const tcid = `${c.table_id}_${c.column_id}`;
      const erow = createNsRow(tcid, "-", c.disabled ? null : onRowClick);
      frag.appendChild(erow);
    });
    edst.replaceChildren(frag);
  }
  isSelected(tableId, colId) {
    return this.selCols.hasOwnProperty(`${tableId}_${colId}`);
  }
}

/*----------------------------------------------------------------------------*/

class NssColumns {
  onUpdateSelection = null;
  nssselection = null;
  
  constructor(dstId, nssselection) {
    this.distId = dstId;
    this.nssselection = nssselection;
    console.log(this.nssselection);
  }
  
  setTable(table, colid) {
    let frag = document.createDocumentFragment();
    let eshow = null;
    const nssc = this;
    table.columns.forEach(c => {
      const onRowClick = function(){
        const doAdd = this.lastChild.innerHTML == "+";
        if (doAdd) {
          this.lastChild.innerHTML = '-';
          nssc.nssselection.addCol(table.id, c.id);
        } else {
          nssc.nssselection.removeCol(table.id, c.id);
        }
      };
      const s = this.nssselection.isSelected(table.id, c.id);
      const erow = createNsRow(c.title, s ? "-" : "+", onRowClick);
      erow.noasTableId = table.id;
      erow.noasColumnId = c.id;
      frag.appendChild(erow);
      if (c.id == colid) {
        eshow = erow;
      }
    });
    document.getElementById(this.distId).replaceChildren(frag);
    if (eshow) {
      eshow.scrollIntoView({behavior: "smooth", block: "center"});
      eshow.classList.add("emph");
    }
  }
  update() {
    Array.from(document.getElementById(this.distId).children).forEach((e) => {
      const s = this.nssselection.isSelected(e.noasTableId, e.noasColumnId);
      e.lastChild.innerHTML = s ? "-" : "+";
    });
  }
}

/*----------------------------------------------------------------------------*/

class SearchItems{
  static get _search_items() {
    return {
      "table.id": {
        type: "table",
        niceName: "ID",
      },
      "table.title": {
        type: "table",
        niceName: "title",
      },
      "table.category": {
        type: "table",
        niceName: "category",
      },
      "column.title": {
        type: "column",
        niceName: "title",
      },
      "column.id": {
        type: "column",
        niceName: "ID",
        weight: 0.5,
      },
      "column.descr": {
        type: "column",
        niceName: "description",
        weight: 0.5,
      },
      "table.descr": {
        type: "table",
        niceName: "description",
        weight: 0.5,
      },
    };
  }

  static get searchKeys() {
    return Object.keys(this._search_items).map(k =>
      {
        const v = this._search_items[k];
        return {
          name: k,
          ...(v.weight !== undefined && {weight: v.weight}) // add weight if defined
        };
      }
    );
  }

  static prettyPrintHit(h) {
    if ("table" in h.item) {
      return "Table: " + h.item.table.title + ` (${h.item.table.id})`;
    }
    if ("column" in h.item) {
      return `Column: ${h.item.column.title}` + ` (${h.item._table.id}_${h.item.column.id})`;
    } 
    throw "search result type not implemented"
  }

  static parseHit(h) {
    if ("table" in h.item) {
      return {
        type: "table",
        title: h.item.table.title,
        id: h.item.table.id,
      };
    }
    if ("column" in h.item) {
      return {
        type: "column",
        title: h.item.column.title,
        id: `${h.item._table.id}_${h.item.column.id}`,
      };
    } 
    throw "search result type not implemented"
  }
}

