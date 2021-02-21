<?php

function sql_build_query($dbmeta, $sel) {
  function _get_sql_select_table($tabmeta, $sel_cols) {
    $r = array();
    $tid = $tabmeta->{"id"};
    # use prefix (tableid_) for column? only non-core tables
    $colid_prefix = $tid == "core" ? "" : "_";
    $as_pfx =  $tid == "core" ? "" :$tid . "_";
    foreach ($tabmeta->{"columns"} as $c) {
      $cid = $c->{"id"};
      // column is selected
      $lcid = $tid . "_" . $cid;
      if (!array_key_exists($lcid, $sel_cols)) {
        continue;
      }
      $sql = "{$tid}.{$colid_prefix}{$cid} AS {$as_pfx}{$cid}";
      array_push($r, $sql);
    }
    return $r;
  }
  function _get_sql_select($dbmeta, $sel_tabs, $sel_cols) {
    $r = array();
    // for all tables
    foreach ($dbmeta->{"tables"} as $t) {
      // if table is selected
      if (!array_key_exists($t->{'id'}, $sel_tabs)) {
        continue;
      }
      $rs = _get_sql_select_table($t, $sel_cols);
      $r = array_merge($r, $rs);
    } 
    return join(",\n", $r);
  }
  function _get_sql_join($dbmeta, $sel_tabs) {
    $r = array();
    foreach ($dbmeta->{"tables"} as $t) {
      $tid = $t->{"id"};
      if (!array_key_exists($tid, $sel_tabs)) {
        continue;
      }
      $sql = "";
      switch ($t->{"sampletype"}) {
        case "core":
          break;
        case "long":
          $sql = "LEFT OUTER JOIN long_{$tid} {$tid} ON core.subject_id={$tid}.subject_id AND core.project_id={$tid}.project_id AND core.wave_code={$tid}.wave_code";
          array_push($r, $sql);
          break;
        case "repeated":
          $sql = "LEFT OUTER JOIN repeated_{$tid} {$tid} ON core.subject_id={$tid}.subject_id AND core.project_id={$tid}.project_id AND core.wave_code={$tid}.wave_code";
          array_push($r, $sql);
          break;
        case "cross":
          $sql = "LEFT OUTER JOIN cross_{$tid} {$tid} ON core.subject_id={$tid}.subject_id";
          array_push($r, $sql);
          break;
        default:
          throw new Exception('Unkown table type: ' . $t->{"sampletype"});
      }
    }
    return join("\n", $r);
  }
  function _get_sql_where_prj($project) {
    if ($project == "all") {
      return "core.subject_shareable = 1";
    }
    return "core.project_id = '{$project}'";
  }
  function _get_sql_where($dbmeta, $sel_tabs, $set_op, $project) {
    if ($set_op == "all") {
      return _get_sql_where_prj($project);
    }
    $b    = $set_op == "intersect" ? "TRUE" : "FALSE";
    $conj = $set_op == "intersect" ? "AND" :  "OR";
    $r = array();
    foreach ($dbmeta->{"tables"} as $t) {
      $tid = $t->{"id"};
      // skip non-included tables and core table
      if (!array_key_exists($tid, $sel_tabs)) {
        continue;
      }
      switch ($t->{"sampletype"}) {
        case "core":
          break;
        case "long":
          $sql = "{$conj} core.subject_id IN (SELECT DISTINCT(subject_id) FROM long_{$tid} t WHERE t.subject_id=core.subject_id AND t.project_id=core.project_id AND t.wave_code=core.wave_code)";
          array_push($r, $sql);
          break;
        case "repeated":
          $sql = "{$conj} core.subject_id IN (SELECT DISTINCT(subject_id) FROM repeated_{$tid} t WHERE t.subject_id=core.subject_id AND t.project_id=core.project_id AND t.wave_code=core.wave_code)";
          array_push($r, $sql);
          break;
        case "cross":
          $sql = "{$conj} core.subject_id IN (SELECT DISTINCT(subject_id) FROM cross_{$tid} t WHERE t.subject_id=core.subject_id)";
          array_push($r, $sql);
          break;
        default:
          throw new Exception('Unkown table type: ' . $t->{"sampletype"});
      }
    }
    $sql_conjunction_conditions = join("\n", $r);
    $sql_where_prj = _get_sql_where_prj($project);
    return "(\n{$b}\n{$sql_conjunction_conditions}\n) AND {$sql_where_prj}";
  }
  function _get_sql_where_repeated($dbmeta, $sel_tabs) {
    $rgroups = array();
    // collect arrays for each group; group_id => [{tab_id, col_id}, ...]
    foreach ($dbmeta->{"tables"} as $t) {
      $tid = $t->{"id"};
      // skip non-included tables
      if (!array_key_exists($tid, $sel_tabs)) {
        continue;
      }
      // has repeated_goup?
      if (!array_key_exists("repeated_group", $t)) {
        continue;
      }
      // init result?
      if (!array_key_exists($t->repeated_group->group_id, $rgroups)) {
        $rgroups[$t->repeated_group->group_id] = array();
      }
      // add new entry
      $rgroups[$t->repeated_group->group_id][] = array(
        "col_id" => $t->repeated_group->col_id
        ,"table_id" => $tid
      );
    }
    // generate where conditions; tab0.col=tabn.col
    $sqls = array();
    foreach ($rgroups as $rg) {
      for ($i=1; $i < count($rg); $i++) { 
        array_push($sqls, 
          "AND ". $rg[0 ]["table_id"] . "._" . $rg[0 ]["col_id"] .
          " = " . $rg[$i]["table_id"] . "._" . $rg[$i]["col_id"]
        );
      }
    }
    return join("\n", $sqls);
  }

  // prepare selection
  $sel_tabs = array();
  // "tableid_colid" as in column header (execption core)
  $sel_cols = array(); 
  // NOTE: instead of sel_tabs and sel_cols,
  //   we could use a map: k:table_id => v:column_ids
  foreach ($sel->{"columns"} as $e) {
    $sel_cols[$e->{"table_id"} . "_" . $e->{"column_id"}] = true;
    $sel_tabs[$e->{"table_id"}] = true;
  }

  $sql_select = _get_sql_select($dbmeta, $sel_tabs, $sel_cols);
  $sql_join   = _get_sql_join($dbmeta, $sel_tabs);
  $sql_where  = _get_sql_where($dbmeta, $sel_tabs, $sel->{"set_op"}, $sel->{"project"});
  $sql_where_repeated = _get_sql_where_repeated($dbmeta, $sel_tabs);
  
  $sql = "
SELECT DISTINCT 
{$sql_select}
FROM core_core AS core
{$sql_join}
WHERE TRUE AND 
{$sql_where}
{$sql_where_repeated}
ORDER BY core.subject_id
";

  return $sql;
}

?>