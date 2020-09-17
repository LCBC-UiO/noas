/*----------------------------------------------------------------------------*/

/* wrapper functions as workaround for unnamed struct on some systems */

function getColumnName(i, coldefs) {
  if (coldefs[i].hasOwnProperty('name')) {
    return coldefs[i].name;
  }
  return coldefs[i][0];
}

function getColumnId(i, coldefs) {
  if (coldefs[i].hasOwnProperty('name')) {
    return coldefs[i].name;
  }
  return i.toString();
}

function getColumnTypeisNumber(i, coldefs) {
  r = false;
  r = r || coldefs[i].typname.startsWith("_int");
  r = r || coldefs[i].typname.startsWith("_float");
  return r
}

/*----------------------------------------------------------------------------*/

var nCalc = function(values, data, calcParams){
  var calc = 0;
  values.forEach(function(value){
    calc++;
  });
  return "n=" + calc.toString();
}

/*----------------------------------------------------------------------------*/


var avgCalc = function(values, data, calcParams){
  var sum = 0;
  var count = 0;
  values.forEach(function(value){
    if (value !== null) {
      sum+=value;
      count++;
    }
  });
  return "avg=" + (sum/count).toPrecision(4);
}

/*----------------------------------------------------------------------------*/

function getColDef(coldefs) {
  res = []
  for (let i = 0; i < coldefs.length; i++) {
    var field = {};
    field["title"] = getColumnName(i, coldefs);
    field["field"] = getColumnId(i, coldefs);
    if (i == 0) {
      field["bottomCalc"] = nCalc;
      field["topCalc"] = nCalc;
      frozen=true;
    } else if (getColumnTypeisNumber(i, coldefs)) {
      field["bottomCalc"] = avgCalc;
      field["topCalc"] = avgCalc;
    }
    res.push(field);
  }
  return (res);
};

/*----------------------------------------------------------------------------*/

var table = new Tabulator("#query-result-table", {
  layout:"fitColumns", 
  pagination:"local",
  paginationSize: 40,
  columns: getColDef(theader),
  downloadConfig:{
    columnCalcs:false,
  },
  /* replace null elements with empty string */
  downloadDataFormatter:function(data){
    data = JSON.parse(JSON.stringify(data).replace(/null/g, '""'))
    return data
  }
});

table.setData(tdata);

/* download buttons */
document.querySelector("#dlcsv").addEventListener('click', function() {
  dlfilename = "noas_query_" + dlinfo["date"] + "_" + dlinfo["time"] + "_" + dlinfo["md5"]
  table.download("csv", dlfilename + ".csv", {delimiter:";"});
});
document.querySelector("#dlxlsx").addEventListener('click', function() {
  dlfilename = "noas_query_" + dlinfo["date"] + "_" + dlinfo["time"] + "_" + dlinfo["md5"]
  table.download("xlsx", dlfilename + ".xlsx", {sheetName:"NOAS download " + dlinfo["md5"] });
});

/* table filter */

var fcolsel = document.querySelector("#filter-column")
for (let i = 0; i < theader.length; i++) {
  var opt = document.createElement('option');
  opt.value = getColumnId(i, theader);
  opt.innerHTML = getColumnName(i, theader);
  fcolsel.appendChild(opt);
}
var ftypesel = document.querySelector("#filter-type")
var types = ["=","<","<=", ">",">=","!=","like","in","regex"]
for (let i = 0; i < types.length; i++) {
  var opt = document.createElement('option');
  opt.value = types[i];
  opt.innerHTML = types[i];
  ftypesel.appendChild(opt);
}

function resetFilter() {
  var column = document.querySelector("#filter-column");
  var type   = document.querySelector("#filter-type");
  var value  = document.querySelector("#filter-value");
  value.value = "";
  column.value = "";
  type.value = types[0];
  table.clearFilter();
  g_filters = [];
  g_currFilter = {};
  updateFilterCount();
}

var g_filters = [];
var g_currFilter = {};


function updateFilterCount() {
  var c = document.querySelector("#filter-count");
  var num = table.getFilters().length;
  var sffx = num == 1 ? "" : "s";
  c.innerHTML = num.toString() + " active filter" + sffx; 
};


function updateFilter() {
  var column = document.querySelector("#filter-column");
  var type   = document.querySelector("#filter-type");
  var value  = document.querySelector("#filter-value");
  if (column.options[column.selectedIndex].value === "") {
    resetFilter();
    return;
  }
  if (table.getFilters().length > 0) {
    table.removeFilter([g_currFilter]);
  }
  g_currFilter = {
    field:column.options[column.selectedIndex].value
    , type:type.options[type.selectedIndex].value
    , value:value.value
  };
  table.addFilter([g_currFilter]);
  updateFilterCount();
}

function addFilter() {
  if (Object.keys(g_currFilter).length != 0) {
    table.addFilter([g_currFilter]);
  }
  updateFilter();
}

function showFilters() {
  var filters = table.getFilters();
  var str = "no filters set";
  for (let i = 0; i < filters.length; i++) {
    str = i == 0 ? "current filters:\n\n" : (str + "AND ");
    str += filters[i].field + " ";
    str += filters[i].type + " ";
    str += filters[i].value + "\n";
  }
  alert(str);
}

document.querySelector("#filter-column").addEventListener('change', updateFilter);
document.querySelector("#filter-type"  ).addEventListener('change', updateFilter);
document.querySelector("#filter-value" ).addEventListener('keyup' , updateFilter);
document.querySelector("#filter-add"   ).addEventListener('click' , addFilter);
document.querySelector("#filter-clear" ).addEventListener('click' , resetFilter);
document.querySelector("#filter-show"  ).addEventListener('click' , showFilters);
