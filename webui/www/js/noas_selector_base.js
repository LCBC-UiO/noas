

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



async function getMetaData() {
  async function _getData(url) {
    const response = await fetch(url, {
      method: 'GET'
    });
    if (!response.ok) {
      throw new Error(response.statusText);
    }
    return response.json();
  }
  try {
    let jsn = await _getData(`./dbmeta.php?prj=${g_prj}`);
    if (!jsn.status_ok) {
      throw Error(jsn.status_msg);
    }
    return jsn.data;
  } catch (e) {
    showAlertBox(AlertType.ERROR, ["Unable to load data.", e.toString()]);
    console.log("err: " + e.toString());
  };
  return {};
}

async function (get_version(){
  const meta = await getMetaData();
  // set version
  {
    const vdateStr = (new Date(meta.version.ts)).toLocaleString();
    let ver = document.getElementById("version-label")
    ver.innerHTML = `${meta.version.label} (${vdateStr})`;
    if (!meta.version.import_completed) {
      const errmsg = [ 
        `Either the last update of the database (${vdateStr}) had an error or the update has not finished yet.`,
        `The data shown here will be incomplete.`
      ];
      showAlertBox(AlertType.ERROR, errmsg);
    }
    let verid = document.createElement("span");
    verid.innerHTML = `${meta.version.id}`;
    verid.id = "version-id";
    verid.hidden = true;
    ver.appendChild(verid);
    return(meta);
  }
})();

const g_prj = (function() {
  const prj = (new URLSearchParams(window.location.search)).get("prj");
  if (!prj) {
    window.location.href = './index.html';
  }
  document.getElementById("spPrj").innerHTML = prj;
  return prj;
})();
