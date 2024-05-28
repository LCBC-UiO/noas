var g_table = null;

async function getTableData(selection) {
    console.log(JSON.stringify(selection))
  const response = await fetch("./php/query_json.php", {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json'
    },
    body: JSON.stringify(selection),
  });
  if (!response.ok) {
    throw new Error(response.statusText);
  }
  console.log(response);

  const jsn = await response.json();
  console.log("here")

  if (!jsn.status_ok) {
    throw Error(jsn.status_msg);
  }

  return jsn.data;
}

function getColDef(coldefs) {
  let colCalcN = function(values, data, calcParams) {
    return "n=" + values.length.toString();
  }
  let colCalcAvg = function(values, data, calcParams){
    values = values.filter(e => e !== null);
    const mean = values.reduce( (a,b) => a + parseFloat(b), 0) / values.length;
    return "m=" + (mean).toPrecision(4);
  }
  let colCalcAvgSd = function(values, data, calcParams){
    values = values.filter(e => e !== null);
    const n = values.length;
    const mean = values.reduce( (a,b) => a + parseFloat(b), 0) / n;
    const sd = Math.sqrt(values.map(x => Math.pow(x - mean, 2)).reduce((a, b) => a + b, 0) / n);
    return `m=${mean.toPrecision(2)} sd=${sd.toPrecision(2)}`;
  }
  return coldefs.map( e => {
    let r = {
      title: e.id,
      field: e.id,
      minWidth: 90
    }
    if (e.idx == 0) {
      r.topCalc = colCalcN;
      r.bottomCalc = colCalcN;
      r.minWidth = 120;
    } else if (e.type == "float" || e.type == "int") {
      r.topCalc = colCalcAvgSd;
      r.bottomCalc = colCalcAvgSd;
      r.sorter = "number";
    }
    return r;
  });
};

function getDataSelection() {
  try {
    const storage = window.sessionStorage.getItem('selection');
    if (!storage) {
      throw new Error("Session expired - Please select columns <a href='./select.html'>here</a>.")
    }
    const sel = JSON.parse(storage);
    return sel;
   } catch (e) {
    showAlertBox(AlertType.ERROR, ["Unable to get selected data.", e.toString()]);
    console.log("err: " + e.toString());
  }
}

function checkSelection(sel_cols) {
  const dbmeta = JSON.parse(window.sessionStorage.getItem('dbmeta'));
  // get table.type and repeated_group info from selections
  const selected_tables = [...new Set(sel_cols.map(c => c.table_id))];
  const r_goups = {};
  const r_ungrouped = [];
  dbmeta.tables.forEach(t => {
    // selected?
    if (!selected_tables.includes(t.id)) {
      return;
    }
    if (t.sampletype != "repeated") {
      return;
    }
    if (t.repeated_group) {
      if (!r_goups.hasOwnProperty(t.repeated_group.group_id)) {
        r_goups[t.repeated_group.group_id] = [];
      }
      r_goups[t.repeated_group.group_id].push(t.id);
    } else {
      r_ungrouped.push(t.id);
    }
  });
  const max_repeated = 1;
  if (Object.keys(r_goups).length + r_ungrouped.length > max_repeated) {
    const msg = [`You selected more than ${max_repeated} tables with timeseries data. NOAS will try to process your query but might fail due to the number of resulting rows. Here is a list of the problematic tables in your selection:`];
    let count = 1;
    Object.keys(r_goups).forEach(k => {
      if (r_goups[k].length > 1) {
        msg.push(`${count}) group "${k}" (tables: ${r_goups[k].join(", ")})`);
      } else {
        msg.push(`${count}) table "${r_goups[k].join(", ")}"`);
      }
      count++;
    });
    r_ungrouped.forEach(e => {
      msg.push(`${count}) table "${e}"`);
      count++;
    })
    showAlertBox(AlertType.WARNING, msg);
  }
}

async function loadTable() {
  try {
    const sel = getDataSelection();
    checkSelection(sel.columns);
    lcProgressInit("noasTable");
    // make db query
    g_table_data = await getTableData(sel);
    document.getElementById("noasTable").innerHTML = '<h4>preparing table...</h4>';
    document.getElementById("spPrj").innerHTML = sel.project;

    // show data in table
    g_table = new Tabulator("#noasTable", {
      layout: "fitDataFill",
      pagination: "local",
      paginationSize: 25,
      columns: getColDef(g_table_data.column_def),
      downloadConfig: {
        columnCalcs: false,
      },
      data: g_table_data.rows,
      /* replace null elements with empty string */
      downloadDataFormatter: function(data){
        data = JSON.parse(JSON.stringify(data).replace(/null/g, '""'))
        console.log(data);
        return data
      },
      tooltipsHeader: true,
      tooltips: true,
    });
    // load "import to r" code
    document.getElementById("codeImportR").innerHTML = await (async function() {
      r = await fetch("./php/r_import.php", {
        method: "POST",
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(sel),
      });
      if (!r.ok) {
        throw `error loading from r_import_txt.php`;
      }
      return await r.text();
    })();
    // encrypted R
    {
      const sel = getDataSelection();
      const md5 = lcGetSelHash(sel);
      const did = lcGetDataVersionFnStr(sel);
      const dat = lcGetDateFnStr(Date.parse(g_table_data.date));
      const dlfn = `noas_enc_${dat}_${md5}_${did}.R`;
      document.getElementById("spExportRId").innerHTML = `${dat}_${md5}_${did}`;
      document.getElementById("codeExportRSource").innerHTML = `source("~/Downloads/${dlfn}")`;
      // set password
      const password = (function(){
        /* https://stackoverflow.com/questions/2450954/how-to-randomize-shuffle-a-javascript-array */
        function _shuffleArray(array) {
          for (var i = array.length - 1; i > 0; i--) {
            var j = Math.floor(Math.random() * (i + 1));
            var temp = array[i];
            array[i] = array[j];
            array[j] = temp;
          }
          return array;
        }
        const tokens = [
          "abcdefghijkmnopqrstuvwxyz",
          "ABCDEFGHJKLMNOPQRSTUVWXYZ",
          "0123456789",
          "-/?!+*"
        ];
        const lengths = [3,3,2,2]; // number of tokens from each group
        return _shuffleArray(
          tokens
            .map(e => e+e+e)
            .map(e => _shuffleArray(e.split("")))
            .map((e,i) => e.slice(0, lengths[i]))
            .flat()
        ).join("");
      })();
      document.getElementById("spExportRPw").innerHTML = password;
      // download button
      document.getElementById("btnDlEncR").onclick = async () => {
        document.getElementById("dProgress").classList.remove("hidden");
        document.getElementById("btnDlEncR").classList.add("hidden");
        const r = await fetch(`./php/r_enc.php?password=${encodeURIComponent(password)}`, {
          method: "POST",
          headers: {
            'Content-Type': 'application/json'
          },
          body: JSON.stringify(sel),
        });
        // rewrite the blobs content-type
        let blob = new Blob([await (await r.blob()).arrayBuffer()], {type : 'application/octet-stream'});
        let edlr = document.getElementById("aDlEncR");
        edlr.download = dlfn;
        edlr.href = window.URL.createObjectURL(blob);
        document.getElementById("dProgress").classList.add("hidden");
        document.getElementById("btnDlEncR").classList.remove("hidden");
        edlr.click();
      }
    }
  } catch (e) {
    showAlertBox(AlertType.ERROR, ["Unable to get table data.", e.toString()]);
    console.log("err: " + e.toString());
  }
}

loadTable();

document.getElementById("btnSave").addEventListener('click', () => lcSaveSelection(getDataSelection()));
document.getElementById("btnDlCsv").addEventListener('click', function() {
  const sel = getDataSelection();
  const md5 = lcGetSelHash(sel)
  const did = lcGetDataVersionFnStr(sel);
  const dlfilename = `noas_query_${lcGetDateFnStr(Date.parse(g_table_data.date))}_${md5}_${did}.csv`;
  g_table.download("csv", dlfilename, {delimiter:";"});
});
document.getElementById("btnModalEncR").onclick = (e) => {
  document.getElementById("btnDlEncR").classList.remove("hidden");
  document.getElementById("dProgress").classList.add("hidden");
};
document.getElementById("btnMarkAllR").onclick = (e) => {
  window.getSelection().selectAllChildren(
    document.getElementById("codeImportR") 
  );
};
document.getElementById("btnBack").addEventListener('click', () => {history.back()});
