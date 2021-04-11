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
    this.nssSelection.onUpdate = () => { this.nssColumns.update(); };
    this.nssSelection.addCol("core", "subject_id", true);
    this.nssSelection.addCol("core", "project_id");
    this.nssSelection.addCol("core", "wave_code");
    this.nssSelection.addCol("core", "subject_sex");


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
      ignoreLocation: true,
      useExtendedSearch: true,
      keys: SearchItems.searchKeys,
    });
  
    document.getElementById("inpSearch").oninput = (e) => doSearch(e, this);
  }

  getSelection(){
    // how to sort selected columns? 
    const idx_tree = {}; // this could be cached by building within ctor
    this.dbmeta.tables.forEach((t,i) => {
      idx_tree[t.id] = {
        i: i,
        columns: {}
      };
      t.columns.forEach((c,j) => {
        idx_tree[t.id].columns[c.id] = {
          i: j
        };
      });
    });
    const sel_cols = this.nssSelection.getSelection();
    sel_cols.sort( (a,b) => {
      const ita = idx_tree[a.table_id].i;
      const itb = idx_tree[b.table_id].i;
      if (ita < itb) return -1;
      if (ita > itb) return  1;
      const ica = idx_tree[a.table_id].columns[a.column_id].i;
      const icb = idx_tree[b.table_id].columns[b.column_id].i;
      if (ica < icb) return -1;
      if (ica > icb) return  1;
      throw "something went wrong - does the selection contain duplicated entries?"
      return 0;
    });
    return sel_cols;
  }

  setSelection(sel_cols){
    this.nssSelection.removeCols(
      this.nssSelection.getSelection()
    );
    this.nssSelection.addCol("core", "subject_id", true);
    this.nssSelection.addCols(sel_cols);
    const ids_found = this.nssSelection.getSelection();
    const ids_bad = sel_cols.filter(x => 
      !ids_found.some(y =>
        (y.table_id == x.table_id && y.column_id == x.column_id)
      )
    );
    return ids_bad;
  }

  clearSelection() {
    this.nssSelection.removeCols(
      this.nssSelection.getSelection()
    );
    this.nssSelection.addCol("core", "subject_id", true);
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
    if (table.repeated_group) {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Data group";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = `${table.repeated_group.group_id} (column: ${table.repeated_group.col_id})`;
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

function createNsRow(textcenter, fasymbol, props) {
  const { onclick, tooltip, tooltip_pos = "left" } = props;
  let erow = document.createElement("div");
  erow.classList.add("resrow");
  if (onclick === null) erow.classList.add("nssdisabled");
  let ecenter = document.createElement("span");
  ecenter.classList.add("resrowcenter");
  erow.appendChild(ecenter);
  ecenter.innerHTML = textcenter;
  if (tooltip) {
    erow.setAttribute("data-toggle", "tooltip");
    erow.setAttribute("data-placement", tooltip_pos);
    erow.setAttribute("title", tooltip);
  }
  let ecaret = document.createElement("div");
  ecaret.classList.add("resrowright");
  ecaret.classList.add("fas");
  ecaret.classList.add(`fa-${fasymbol}`);
  ecaret.classList.add("fa-lg");
  erow.appendChild(ecaret);
  erow.onclick = onclick;
  return erow;
}
function hasIconNsRow(r, fasymbol) {
  return r.lastElementChild.getAttribute("data-icon") == fasymbol;
}
function setIconNsRow(r, fasymbol) {
  r.lastElementChild.setAttribute("data-icon", fasymbol);
}

/*----------------------------------------------------------------------------*/

function doSearch(e, nss) {
  const sres = e.target.value ? nss.fuse.search(e.target.value) : [];
  let frag = document.createDocumentFragment();
  const maxResults = 40;
  sres.slice(0, maxResults).forEach(r => {
    const rowonclick = () => nss.showTable(
      r.item.table  ? r.item.table : r.item._table, 
      r.item.column ? r.item.column.id : null
      );
      const mi = SearchItems.getMatchInfo(r);
      const text = SearchItems.prettyPrintMatchInfo(mi);
      frag.appendChild(
        createNsRow(text, "chevron-right", {
          onclick: rowonclick,
          tooltip: `${text} matching "${mi.found_in}"`,
          tooltip_pos: "right"
        })
        );
      });
  $('[data-toggle="tooltip"]').tooltip('dispose');
  document.getElementById("nssResults").innerHTML = '';
  document.getElementById("nssResults").appendChild(frag);
  $('[data-toggle="tooltip"]').tooltip({ boundary: 'window'});
}

/*----------------------------------------------------------------------------*/

class NssSelection {
  onUpdate = null;
  selCols = {};

  static get SymbolRemove() { return "backspace"; }

  constructor(dstId, dbmeta) {
    this.distId = dstId;
  }
  set onUpdate(onUpdate) { this.onUpdate = onUpdate; }
  setSelection(sel_cols) {
    // this.selCols = sel_cols;
    let frag = document.createDocumentFragment();
  }
  getSelection() {
    return Object.keys(this.selCols).map(k => {
      return {
        table_id: this.selCols[k].table_id,
        column_id: this.selCols[k].column_id,
      };
    });
  }
  addCol(tableId, colId, disabled = false) {
    this.selCols[`${tableId}_${colId}`] = {
      table_id: tableId,
      column_id: colId,
      disabled: disabled,
    };
    this.render();
    this.onUpdate();
  }
  addCols(cols) {
    cols.forEach(c => {
      if (this.isSelected(c.table_id, c.column_id)) {
        return;
      }
      this.selCols[`${c.table_id}_${c.column_id}`] = {
        table_id: c.table_id,
        column_id: c.column_id,
        disabled: c.disabled,
      };
    });
    this.render();
    this.onUpdate();
  }
  removeCol(tableId, colId) {
    if (this.selCols[`${tableId}_${colId}`].disabled) {
      return false;
    }
    delete this.selCols[`${tableId}_${colId}`];
    this.render();
    this.onUpdate();
    return true;
  }
  removeCols(cols) {
    cols.forEach(c => {
      if (this.selCols[`${c.table_id}_${c.column_id}`].disabled) {
        return;
      }
      delete this.selCols[`${c.table_id}_${c.column_id}`];
    });
    this.render();
    this.onUpdate();
  }
  render() {
    let edst = document.getElementById(this.distId);
    const keys = Object.keys(this.selCols);
    edst.parentElement.firstElementChild.innerHTML = "";
    const eicon = document.createElement("i");
    eicon.classList.add("fas");
    eicon.classList.add("fa-shopping-cart");
    eicon.classList.add("mr-2");
    edst.parentElement.firstElementChild.appendChild(eicon);
    edst.parentElement.firstElementChild.appendChild(
      document.createTextNode(`Selections (${keys.length})`)
    );
    let frag = document.createDocumentFragment();
    keys.forEach(k => {
      const c = this.selCols[k];
      const onRowClick = () => {
        this.removeCol(c.table_id, c.column_id);
      };
      const tcid = `${c.table_id}_${c.column_id}`;
      const erow = createNsRow(tcid, NssSelection.SymbolRemove, {onclick: c.disabled ? null : onRowClick});
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

  static get SymbolAdd()    { return "plus-circle"; }
  static get SymbolRemove() { return "backspace"; }
  
  constructor(dstId, nssselection) {
    this.distId = dstId;
    this.nssselection = nssselection;
  }
  
  setTable(table, colid) {
    let frag = document.createDocumentFragment();
    let eshow = null;
    const nssc = this;
    table.columns.forEach(c => {
      const onRowClick = function(){
        const doAdd = hasIconNsRow(this, NssColumns.SymbolAdd);
        if (doAdd) {
          nssc.nssselection.addCol(table.id, c.id);
        } else {
          nssc.nssselection.removeCol(table.id, c.id);
        }
      };
      const s = this.nssselection.isSelected(table.id, c.id);
      const erow = createNsRow(
        c.title, 
        s ? NssColumns.SymbolRemove : NssColumns.SymbolAdd, {
          onclick: onRowClick, 
          tooltip: [
              (c.descr ? `Description: ${c.descr}` : null),
              (c.type ? `Type: ${c.type}` : null),
              `ID: ${table.id}_${c.id}`, 
            ].filter(e => e).join("; "),
          tooltip_pos: "left",
        }
      );
      erow.noasTableId = table.id;
      erow.noasColumnId = c.id;
      frag.appendChild(erow);
      if (c.id == colid) {
        eshow = erow;
      }
    });
    document.getElementById(this.distId).replaceChildren(frag);
    $('[data-toggle="tooltip"]').tooltip({ boundary: 'window'});
    if (eshow) {
      eshow.scrollIntoView({behavior: "smooth", block: "center"});
      eshow.classList.add("emph");
    }
  }
  update() {
    Array.from(document.getElementById(this.distId).children).forEach((e) => {
      const s = this.nssselection.isSelected(e.noasTableId, e.noasColumnId);
      setIconNsRow(e, s ? NssColumns.SymbolRemove : NssColumns.SymbolAdd);
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
        weight: 0.8,
      },
      "table.descr": {
        type: "table",
        niceName: "description",
        weight: 0.6,
      },
      "column.title": {
        type: "column",
        niceName: "title",
        weight: 0.8,
      },
      "column.id": {
        type: "column",
        niceName: "ID",
        weight: 0.6,
      },
      "column.descr": {
        type: "column",
        niceName: "description",
        weight: 0.6,
      },
      "_table.id": {
        type: "column",
        niceName: "table ID",
        weight: 0.2,
      },
      "_table.title": {
        type: "column",
        niceName: "table title",
        weight: 0.2,
      },
      "_table.category": {
        type: "column",
        niceName: "table category",
        weight: 0.2,
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

  static getMatchInfo(hit) {
    const mi = {
      type: null,
      id: null,
      title: null,
      found_in: null,
    }
    if ("table" in hit.item) {
      mi.type = "table";
      mi.id = hit.item.table.id;
      mi.title = hit.item.table.title;
    } else if ("column" in hit.item) {
      mi.type = "column";
      mi.id = `${hit.item._table.id}_${hit.item.column.id}`
      mi.title = hit.item.column.title;
    }
    mi.found_in = SearchItems._search_items[hit.matches[0].key].niceName;
    return mi;
  }

  static prettyPrintMatchInfo(mi) {
    return `${mi.type[0].toUpperCase() + mi.type.slice(1)}: ${mi.title} (${mi.id})`;
  }
}

