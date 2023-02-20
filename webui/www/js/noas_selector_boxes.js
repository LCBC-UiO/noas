class NoasSelectorBoxes extends NoasSelectorBase {
  constructor(dstId, dbmeta) {
    super(dstId, dbmeta);
  }

  render() {
    let frag = document.createDocumentFragment();
    this.dbmeta.tables.forEach((e,i) => {
      let eOptbox = document.createElement('div');
      frag.appendChild(eOptbox);
      eOptbox.classList.add("accordion-item");
      // hide box if n=0
      if (!e.n) {
        eOptbox.classList.add("hidden");
      }
      eOptbox.id = `noasTable_${e.id}`;
      // box header
      let eOpthead = document.createElement('h2');
      eOptbox.appendChild(eOpthead);
      eOpthead.id = `head-${e.id}`; 
      eOpthead.classList = "accordion-header";
      let eOptheadSpan = document.createElement('button');
      eOpthead.appendChild(eOptheadSpan);
      eOptheadSpan.classList = "accordion-button bg-primary text-white collapsed";
      eOptheadSpan.type = "button";
      eOptheadSpan.setAttribute("data-bs-toggle", "collapse");
      eOptheadSpan.setAttribute("data-bs-target", `#collapse-${e.id}`);
      eOptheadSpan.setAttribute("aria-expanded", "false");
      eOptheadSpan.setAttribute("aria-controls", `collapse-${e.id}`);
      
      const strCategory = e.category.length ? `[${e.category.join(", ")}] ` : '';
      eOptheadSpan.insertAdjacentHTML('beforeend',
        `<small>${strCategory}</small>&nbsp;${e.title} (${e.id}; n=${e.n})&nbsp;`
      );

      // tooltip
      if (e.descr) {
        let eDescr = document.createElement('span');
        eOptheadSpan.appendChild(eDescr);
        eDescr.setAttribute("data-bs-toggle", "tooltip");
        eDescr.setAttribute("data-bs-placement", "top");
        eDescr.setAttribute("title", e.descr);
        {
          let eIcon = document.createElement('span');
          eDescr.appendChild(eIcon);
          eIcon.classList = "fas fa-info-circle small";
          eIcon.style = "z-index: 99;"
        }
      }
      // box body (columns)
      let eOptbody = document.createElement('div');
      eOptbox.appendChild(eOptbody);
      eOptbody.classList = "accordion-collapse collapse";
      eOptbody.id = `collapse-${e.id}`;
      eOptbody.setAttribute("aria-labelledby", `head-${e.id}`)
      eOptbody.setAttribute("data-bs-parent", "#noasTables")
      let eOptcontent = document.createElement('div');
      eOptbody.appendChild(eOptcontent);
      eOptcontent.classList = "accordion-body";
      // columns
      let eRow = document.createElement("div");
      eOptcontent.appendChild(eRow);
      eRow.classList.add("row");
      e.columns.forEach((ec,i) => {
        let eCol = document.createElement("div");
        eRow.appendChild(eCol);
        eCol.classList = "col-sm-3 mb-2 mr-2 form-group form-check";
        let eLabel = document.createElement("label");
        eCol.appendChild(eLabel);
        eLabel.classList = "form-check-label font-weight-normal";
        let eCheck = document.createElement("input");
        eLabel.appendChild(eCheck);
        eCheck.id = `colcheck_${e.id}_${ec.id}`;
        eCheck.type = 'checkbox';
        eCheck.classList = "mr-3";
        eCheck.noasTableId = e.id;
        eCheck.noasColId = ec.id;
        eCheck.value = "1";
        eLabel.insertAdjacentHTML('beforeend', ec.title)
        // column descr tooltip
        if (ec.descr) {
          eLabel.insertAdjacentHTML('beforeend', "&nbsp;")
          let eDescr = document.createElement('span');
          eLabel.appendChild(eDescr);
          eDescr.setAttribute("data-bs-toggle", "tooltip");
          eDescr.setAttribute("data-bs-placement", "top");
          eDescr.setAttribute("title", ec.descr);
          {
            let eIcon = document.createElement('span');
            eDescr.appendChild(eIcon);
            eIcon.classList = "fas fa-info-circletext-muted small";
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
          let doSel = e.target.innerHTML == strSelAll;
          e.target.innerHTML = doSel ? strUnselAll : strSelAll;
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