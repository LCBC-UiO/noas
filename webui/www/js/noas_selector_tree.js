
  
class NoasSelectorTree extends NoasSelectorBase {
  root = null;
  transform = null;
  svg = null;
  duration = 750;
  _node_counter = 0;

  constructor(dstId, meta) {
    super(dstId, meta);
    this.treemap = d3.tree().nodeSize([30,30]);
    // convert dbmeta to tree structure
    this.treeData = ((m) => {
      function _getPath(table) {
        if (table.id == "core") {
          return [];
        }
        return ["non_core"].concat(table.category.length ? table.category : ["uncategorized"]);
      }
      function _insertTableNode(tree, path, node) {
        // insert category?
        if (path.length) {
          const category = path[0];
          let tnext = tree.children.filter(e => e.id == category)[0];
          // create new category;
          if (tnext == undefined) {
            tnext = {
              id: category,
              children: [],
            }
            tree.children.push(tnext);
          }
          _insertTableNode(tnext, path.slice(1), node);
          return;
        }
        // create table node?
        delete Object.assign(node, {["children"]: node["columns"]})["columns"];
        tree.children.push(node);
      }
  
      let tree = {
        id: "noas_data",
        children: []
      };
      m.tables.filter(e => e.n > 0).forEach(e => {
        const path = _getPath(e);
        _insertTableNode(tree, path, e);  
      });
      return(tree);
    })(JSON.parse(JSON.stringify(meta))); // deep copy
  }

  render() {
    let eNoasTables = document.getElementById(this.dstId);
    eNoasTables.innerHTML = '';

    let enst = document.createElement("div");
    enst.id = "nst";
    eNoasTables.append(enst);
    {
      let erow = document.createElement("div");
      erow.classList.add("row");
      enst.append(erow);
      {
        let eside = document.createElement("div");
        eside.classList.add("side");
        erow.append(eside);
        {
          let esi = document.createElement("div");
          esi.id = "sideinner";
          eside.append(esi);
          {
            let esinf = document.createElement("div");
            esinf.id = "selInfo";
            esi.append(esinf);
          }
          {
            let ehinf = document.createElement("div");
            ehinf.id = "hoverInfo";
            esi.append(ehinf);
          }
        }
        let emain = document.createElement("div");
        emain.classList.add("main");
        erow.append(emain);
        {
          let etree = document.createElement("div");
          etree.id = "tree";
          emain.append(etree);
        }
      }
    }
    // Set the dimensions and margins of the diagram
    var margin = {top: 20, right: 390, bottom: 30, left: 90};
    var width  = document.querySelector(`#${this.dstId} .main`).width;
    var height = document.querySelector(`#${this.dstId} #tree`).offsetHeight;

    // console.log(height);

    // append the svg object to the body of the page
    // appends a 'group' element to 'svg'
    // moves the 'group' element to the top left margin
    this.svg = d3.select("#tree").append("svg")
        // .attr("width", width + margin.right + margin.left)
        // .attr("height", height + margin.top + margin.bottom)
        .attr("width", "100%")
        .attr("height", height)
      .append("g")
        .attr("transform", "translate("
              + margin.left + "," + margin.top + ")");

    
    // Assigns parent, children, height, depth
    this.root = d3.hierarchy(this.treeData, function(d) { return d.children; });
    this.root.x0 = height / 2;
    this.root.y0 = 0;

    // Collapse after the second level
    this.root.children[0].children.forEach(_nodeCollapse);
    this.root.children[1].children.forEach(_nodeCollapse);
    //collapse(root);

    const selection = [
      {
        "table_id": "core",
        "column_id": "subject_id"
      },
      {
        "table_id": "core",
        "column_id": "project_id"
      },
      {
        "table_id": "core",
        "column_id": "wave_code"
      },
      {
        "table_id": "core",
        "column_id": "subject_sex"
      }
    ];
    this.setSelection(selection);
    
    // fit to page
    {
      this.transform = d3.zoomTransform(d3.select("g"));
      var hmax = d3.max(d3.selectAll("g.node").data(), e => e.x);
      var hmin = d3.min(d3.selectAll("g.node").data(), e => e.x);
      var wmax = d3.max(d3.selectAll("g.node").data(), e => e.y);
      var wmin = d3.min(d3.selectAll("g.node").data(), e => e.y);

      this.transform.x = margin.left - wmin;
      this.transform.y = margin.top  - hmin;
      d3.select("body")
      .select("svg")
        .select("g")
        .transition()
        .duration(this.duration)
          .attr("transform", this.transform)
      ;
    }
    
    d3.select("svg").call(d3.drag()
      .on("start", () => drag_start(this))
      .on("drag", (event, d) => drag_drag(this, event, d))
      .on("end", () => drag_end(this))
    );   

    function drag_start(nst) {
      d3.select("svg").classed("grabbing", true);
      nst.transform = d3.zoomTransform(d3.select('g').node());
    }
    function drag_drag(nst, event, d) {
      //d = event.sourceEvent.originalTarget;
      nst.transform.x += event.dx;
      nst.transform.y += event.dy;
      d3.select("body").select("svg").select("g").attr("transform", nst.transform);
    }
    function drag_end(nst) {
      d3.select("svg").classed("grabbing", false);
    }

    function _zoomed(nst, {transform}) {
      nst.transform = transform;
      d3.select("g").attr("transform", nst.transform);
    }
    d3.select("svg")
      .call(
        d3.zoom()
          .extent([[0, 0], [400, 400]])
          .scaleExtent([1/4, 8])
          .on("zoom", (props) => _zoomed(this, props))
      ).on("dblclick.zoom", null);

    window.onresize = () => {
      var height = document.querySelector("#tree").offsetHeight;
      d3.select("#tree svg").attr("height", height);
    };
  }

  getSelection() {
    function _nodeGetSel(d) {
      if (d.checked) {
        return [{ table_id: d.parent.data.id, column_id: d.data.id }];
      }
      let ret = [];
      ["_children", "children"].forEach(k => {
        if (!d[k]) {
          return;
        }
        d[k].forEach(e => {
          ret = ret.concat(_nodeGetSel(e));
        });
      });
      return ret;
    }
    return _nodeGetSel(this.root);
  }

  clearSelection() {
    this.setSelection([]);
  }

  setSelection(sel_cols) {
    this.root.children[0].children.forEach(_nodeCollapse);
    this.root.children[1].children.forEach(_nodeCollapse);
    let scmap = {};
    sel_cols.push({table_id: "core", column_id: "subject_id"});
    sel_cols.forEach(e => {
      if (! Object.keys(scmap).includes(e.table_id)) {
        scmap[e.table_id] = [];
      }
      scmap[e.table_id].push(e.column_id);
    });
    _nodeSelect(this.root, scmap);
    _nodeDisable(this.root, { core: ["subject_id"] });
    this._update(this.root, this);
    _updateSelected(this);
    const ids_found = this.getSelection();
    const ids_bad = sel_cols.filter(x => 
      !ids_found.some(y =>
        (y.table_id == x.table_id && y.column_id == x.column_id)
      )
    );
    return ids_bad;
  }

  _update(source, nst) {
    // Assigns the x and y position for the nodes
    var treeData = nst.treemap(nst.root);

    // Compute the new tree layout.
    var nodes = treeData.descendants(),
        links = treeData.descendants().slice(1);

    // Normalize for fixed-depth.
    nodes.forEach(function(d){ d.y = d.depth * 240});
    
    // Update the nodes...
    var node = nst.svg.selectAll('g.node')
        .data(nodes, function(d) {return d.id || (d.id = ++nst._node_counter); });

    // Enter any new modes at the parent's previous position.
    var nodeEnter = node.enter().append('g')
        .attr('class', function(d) {
          let classlist = ["node"];
          if (! d.data.children) classlist.push("column");
          else if (d.data.title) classlist.push("table");
          else classlist.push("category");
          return classlist.join(" ");
        })
        .attr("transform", function(d) {
          return "translate(" + source.y0 + "," + source.x0 + ")";
      })
      .on('mouseover', function(e, d) {
        d3.select(this).classed('emph', true);
        _nodeMouseover(d);
      })
      .on('mouseout', function(e, d) {
        d3.select(this).classed('emph', false)
        _nodeMouseout(d);
      });

    // Toggle children on click.
    function click (event, d) {
      if (d.children) {
        d._children = d.children;
        d.children = null;
        nst._update(d, nst);
      } else {
        d.children = d._children;
        d._children = null;
        nst._update(d, nst);
      }
      event.stopPropagation();
    }

    // Toggle children on click.
    function clickCheckbox (event, d) {
      if (d.disabled) {
        return;
      }
      d.checked = !d.checked;
      nst._update(d, nst);
      _updateSelected(nst);
      event.stopPropagation();
    }

    nodeEnter.filter(".table,.category")
      .on('click', click);
    // Add Circle for the nodes
    nodeEnter.filter(".table,.category").append('circle')
        .attr('r', 1e-6)
        ;
    
    nodeEnter.filter(".column").append('rect')
        .attr('width',  1e-6)
        .attr('height', 1e-6)
        .attr('y', 0)
        .attr('x', 0)
        ;
    
      

    {
      const path_checkmark = d3.line()([[-6, 0], [-1, 5], [5, -5]]);
      nodeEnter.filter(".column").append('path')
        .attr("d", path_checkmark)
      ;
    }

    //node.selectAll(".node.column").enter().append("text").text("sdf");
    //nodeEnter.filter(".column").append("text").text("sdf");
    
    node.select('text')
      .merge(nodeEnter.append("text").style('fill-opacity', 1e-6))
        .text(function (d) {
          if (isTable(d.data)) {
            return `${d.data.id}; n=${d.data.n}` + (d.data.descr ? " ⓘ" : "");
          }
          return (d.data.title ?? d.data.id) + (d.data.descr ? " ⓘ" : ""); 
        })
        .attr("text-anchor", "middle")
        .attr("y", "0.35em")
        .transition().duration(nst.duration)
          .style('fill-opacity', 1)
          .attr("x", function(d) {
            return (this.getBBox().width/2 + 13) * (d.children ? -1 : 1);
          });
        ;
    // UPDATE
    var nodeUpdate = nodeEnter.merge(node);

    // Transition to the proper position for the node
    nodeUpdate.transition()
      .duration(nst.duration)
      .attr("transform", function(d) { 
          return "translate(" + d.y + "," + d.x + ")";
      });

    // Update the node attributes and style
    nodeUpdate.select('.node circle')
      .style("fill", function(d) {
            return d._children ? "rgb(206, 224, 151)" : "rgb(236, 240, 224)";
      })
      .transition()
        .attr('r', 10);

    nodeUpdate.filter('.column')
      .on('click', clickCheckbox)
      .classed("checked", d => d.checked)
      .classed("disabled", d => d.disabled)
      ;
    
    nodeUpdate.select('.node rect').transition()
        .attr('width',  18)
        .attr('height', 18)
        .attr('y', -9)
        .attr('x', -9)
        ;
    
    // Remove any exiting nodes
    var nodeExit = node.exit().transition()
        .duration(nst.duration)
        .attr("transform", function(d) {
            return "translate(" + source.y + "," + source.x + ")";
        })
        .remove();

    // On exit reduce the node circles size to 0
    nodeExit.select('circle')
      .attr('r', 1e-6);
    nodeExit.select('rect')
      .attr('height', 1e-6)
      .attr('width', 1e-6)
      .attr('y', -0)
      .attr('x', -0)

    // On exit reduce the opacity of text labels
    nodeExit.selectAll('text')
      .style('fill-opacity', 1e-6);

    // ****************** links section ***************************

    // Update the links...
    var link = nst.svg.selectAll('path.link')
        .data(links, function(d) { return d.id; });

    // Enter any new links at the parent's previous position.
    var linkEnter = link.enter().insert('path', "g")
        .attr("class", "link")
        .attr('d', function(d){
          var o = {x: source.x0, y: source.y0}
          return diagonal(o, o)
        });

    // UPDATE
    var linkUpdate = linkEnter.merge(link);

    // Transition back to the parent element position
    linkUpdate.transition()
        .duration(nst.duration)
        .attr('d', function(d){ return diagonal(d, d.parent) });

    // Remove any exiting links
    var linkExit = link.exit().transition()
        .duration(nst.duration)
        .attr('d', function(d) {
          var o = {x: source.x, y: source.y}
          return diagonal(o, o)
        })
        .remove();

    // Store the old positions for transition.
    nodes.forEach(function(d){
      d.x0 = d.x;
      d.y0 = d.y;
    });

    // Creates a curved (diagonal) path from parent to the child nodes
    function diagonal(s, d) {
      let path = `M ${s.y} ${s.x}
                  C ${(s.y + d.y) / 2} ${s.x},
                    ${(s.y + d.y) / 2} ${d.x},
                    ${d.y} ${d.x}`;
      return path;
    }

    
  }

}



// Collapse the node and all it's children
function _nodeCollapse(d) {
  if(d.children) {
    d._children = d.children
    d._children.forEach(_nodeCollapse)
    d.children = null
  }
}
function _nodeSelect(d, scmap) {
  // is selected?
  let s = true;
  s = s && d.parent;
  s = s && (!d._children || !d.children);
  s = s && Object.keys(scmap).includes(d.parent.data.id)
  s = s && scmap[d.parent.data.id].includes(d.data.id);
  d.checked = s;
  if(d._children) {
    d._children.forEach(dc => _nodeSelect(dc, scmap))
  }
  if(d.children) {
    d.children.forEach(dc => _nodeSelect(dc, scmap))
  }
}
function _nodeDisable(d, scmap) {
  // is disabled?
  let s = true;
  s = s && d.parent;
  s = s && (!d._children || !d.children);
  s = s && Object.keys(scmap).includes(d.parent.data.id)
  s = s && scmap[d.parent.data.id].includes(d.data.id);
  d.disabled = s;
  if(d._children) {
    d._children.forEach(dc => _nodeDisable(dc, scmap))
  }
  if(d.children) {
    d.children.forEach(dc => _nodeDisable(dc, scmap))
  }
}
function isTable (t) { return t.n !== undefined;}
function isCategory (t) { return t.n === undefined && t.title === undefined;} 

function _nodeMouseover(d) {
  let esi = document.getElementById("hoverInfo");
  esi.innerHTML = "";
  let dl = document.createElement("dl");
  esi.appendChild(dl);
  if (isTable(d.data)) {
    {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Table";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = d.data.title;
    }
    {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "ID";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = d.data.id;
    }
    {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "n";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = d.data.n;
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
      }[d.data.sampletype];
    }
    if (d.data.repeated_group) {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Data group";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = `${d.data.repeated_group.group_id} (column: ${d.data.repeated_group.col_id})`;
    }
    if (d.data.descr) {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Description";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = d.data.descr;
    }
  } else if (isCategory(d.data)) {
    {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Category";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = d.data.id;
    }
  } else {
    {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Column";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = d.data.title;
    }
    {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "ID";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = `${d.parent.data.id}_${d.data.id}`;
    }
    if (d.data.type) {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Type";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = d.data.type;
    }
    if (d.data.descr) {
      let dt = document.createElement("dt");
      dl.appendChild(dt);
      dt.innerHTML = "Description";
      let dd = document.createElement("dd");
      dl.appendChild(dd);
      dd.innerHTML = d.data.descr;
    }
  }
}
function _nodeMouseout() {
  document.getElementById("hoverInfo").innerHTML = "";
}
function _updateSelected(nst) {
  const sel_cols = nst.getSelection();
  let esi = document.getElementById("selInfo");
  esi.innerHTML = "";
  let ep = document.createElement("p");
  ep.innerHTML = `${sel_cols.length} column${ sel_cols.length == 1 ? "" : "s"} selected`;
  esi.appendChild(ep);
}