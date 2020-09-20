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
  function _get_sql_where($dbmeta, $sel_tabs, $set_op) {
    if ($set_op == "all") {
      return "TRUE";
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
    return "(\n{$b}\n{$sql_conjunction_conditions}\n)";
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
  $sql_where  = _get_sql_where($dbmeta, $sel_tabs, $sel->{"set_op"});
  
  $sql = "
SELECT
{$sql_select}
FROM core_core AS core
{$sql_join}
WHERE TRUE AND 
{$sql_where}
ORDER BY core.subject_id, core.project_id, core.wave_code
";

  return $sql;
}

?>