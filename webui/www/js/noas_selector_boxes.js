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

class NoasSelectorBoxes extends NoasSelectorBase {
  constructor(dstId, dbmeta) {
    super(dstId, dbmeta);
  }

  render() {
    let frag = document.createDocumentFragment();
    this.dbmeta.tables.forEach((e,i) => {
      let eOptbox = document.createElement('div');
      frag.appendChild(eOptbox);
      eOptbox.classList.add("optbox");
      // hide box if n=0
      if (!e.n) {
        eOptbox.classList.add("hidden");
      }
      eOptbox.id = `noasTable_${e.id}`;
      // box header
      let eOpthead = document.createElement('div');
      eOptbox.appendChild(eOpthead);
      eOpthead.classList.add("opthead");
      let eOptheadSpan = document.createElement('span');
      eOpthead.appendChild(eOptheadSpan);
      eOptheadSpan.classList.add("optopener");
      let eArrow = document.createElement('i');
      eOptheadSpan.append(eArrow);
      eArrow.classList.add("ddarrow");
      const strCategory = e.category.length ? `[${e.category.join(", ")}] ` : '';
      eOptheadSpan.insertAdjacentHTML('beforeend',
        `${strCategory}${e.title} (${e.id}; n=${e.n})`
      );
      // open / close
      eOptheadSpan.addEventListener('click', () => {
        eOptbody.classList.toggle('openoptbody');
        eArrow.classList.toggle('openddarrow');
      });
      // tooltip
      if (e.descr) {
        let eDescr = document.createElement('span');
        eOpthead.appendChild(eDescr);
        eDescr.classList.add("ml-3");
        eDescr.setAttribute("data-toggle", "tooltip");
        eDescr.setAttribute("data-placement", "top");
        eDescr.setAttribute("title", e.descr);
        {
          let eIcon = document.createElement('span');
          eDescr.appendChild(eIcon);
          eIcon.classList.add("fas");
          eIcon.classList.add("fa-info-circle");
          eIcon.classList.add("small");
        }
      }
      // box body (columns)
      let eOptbody = document.createElement('div');
      eOptbox.appendChild(eOptbody);
      eOptbody.classList.add("optbody");
      let eOptcontent = document.createElement('div');
      eOptbody.appendChild(eOptcontent);
      eOptcontent.classList.add("optcontent");
      eOptcontent.classList.add("container");
      eOptcontent.classList.add("mx-1");
      // columns
      let eRow = document.createElement("div");
      eOptcontent.appendChild(eRow);
      eRow.classList.add("row");
      e.columns.forEach((ec,i) => {
        let eCol = document.createElement("div");
        eRow.appendChild(eCol);
        eCol.classList.add("col-sm-3");
        eCol.classList.add("mb-2");
        eCol.classList.add("form-group");
        eCol.classList.add("form-check");
        let eLabel = document.createElement("label");
        eCol.appendChild(eLabel);
        eLabel.classList.add("form-check-label");
        eLabel.classList.add("font-weight-normal");
        let eCheck = document.createElement("input");
        eLabel.appendChild(eCheck);
        eCheck.id = `colcheck_${e.id}_${ec.id}`;
        eCheck.type = 'checkbox';
        eCheck.classList.add("mr-3");
        eCheck.noasTableId = e.id;
        eCheck.noasColId = ec.id;
        eCheck.value = "1";
        eLabel.insertAdjacentHTML('beforeend', ec.title)
        // column descr tooltip
        if (ec.descr) {
          eLabel.insertAdjacentHTML('beforeend', "&nbsp;")
          let eDescr = document.createElement('span');
          eLabel.appendChild(eDescr);
          eDescr.setAttribute("data-toggle", "tooltip");
          eDescr.setAttribute("data-placement", "top");
          eDescr.setAttribute("title", ec.descr);
          {
            let eIcon = document.createElement('span');
            eDescr.appendChild(eIcon);
            eIcon.classList.add("fas");
            eIcon.classList.add("fa-info-circle");
            eIcon.classList.add("text-muted");
            eIcon.classList.add("small");
          }
        }
      });
      // select all button
      if (i > 0) {
        let eSelAll = document.createElement('a');
        eOptcontent.appendChild(eSelAll);
        eSelAll.classList.add("opt-selectall");
        eSelAll.classList.add("mt-2");
        const strSelAll = "Select all";
        const strUnselAll = "Unselect all";
        eSelAll.insertAdjacentHTML('beforeend', "Select all");
        eSelAll.addEventListener('click', (e) => {
          let doSel = e.srcElement.innerHTML == strSelAll;
          e.srcElement.innerHTML = doSel ? strUnselAll : strSelAll;
          eOptcontent.querySelectorAll("input").forEach(e => {
            e.checked = doSel;
          })
        });
      }
    });
    document.getElementById(this.dstId).replaceChildren(frag);
    // preselect some cols
    let ecbcsubj = document.querySelector("#colcheck_core_subject_id");
    ecbcsubj.checked = true;
    ecbcsubj.disabled = true;
    document.querySelector("#colcheck_core_project_id").checked = true;
    document.querySelector("#colcheck_core_wave_code").checked = true;
    document.querySelector("#colcheck_core_subject_sex").checked  = true;
    // open default boxes
    document.querySelector("#noasTable_core span").click();
    // enable bs tooltips
    $('[data-toggle="tooltip"]').tooltip({ boundary: 'window' });
  }

  getSelection() {
    let columns = [];
    let cbs = document.querySelectorAll(`#${this.dstId} [id^='colcheck_']`);
    cbs.forEach(e => {
      if (!e.checked) {
        return;
      }
      columns.push({table_id: e.noasTableId, column_id: e.noasColId});
    });
    return columns;
  }

  clearSelection() {
    document.querySelectorAll(`#${this.dstId} [id^='colcheck_']`).forEach(e => e.checked = false);
    // check subjid
    document.querySelector(`#${this.dstId} #colcheck_core_subject_id`).checked = true;
  }

  setSelection(columns) {
    this.clearSelection();
    // apply selection
    let idsNotFound = [];
    // column checkboxes
    columns.forEach(e => {
      let checkid = `#${this.dstId} #colcheck_${e.table_id}_${e.column_id}`;
      let cb = document.querySelector(checkid);
      if (!cb) {
        idsNotFound.push(e);
        return;
      }
      cb.checked = true;
    });
    return idsNotFound;
  }

};