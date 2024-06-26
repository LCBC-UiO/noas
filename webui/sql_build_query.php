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

    $rg = _get_sql_select_repeated($dbmeta, $sel_tabs, $sel_cols);
    // if $rg not null, merge $r and $rg
    if (!is_null($rg)) {
      $r = array_merge($r, $rg);
    }
    return join(",\n", $r);
  }
  function _get_sql_join($dbmeta, $sel_tabs, $set_op) {
    function getJoinString($set_op) {
      if ($set_op === "union") {
          return "LEFT JOIN";
      } elseif ($set_op === "intersect") {
          return "LEFT JOIN";
      } else {
        return "FULL JOIN";
      }
    }
    $joinString = getJoinString($set_op);
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
          $sql = "{$joinString} noas_{$tid} {$tid} ON core.subject_id={$tid}.subject_id AND core.project_id={$tid}.project_id AND core.wave_code={$tid}.wave_code";
          array_push($r, $sql);
          break;
        case "repeated":
          $sql = "{$joinString} noas_{$tid} {$tid} ON core.subject_id={$tid}.subject_id AND core.project_id={$tid}.project_id AND core.wave_code={$tid}.wave_code";
          array_push($r, $sql);
          break;
        case "cross":
          $sql = "{$joinString} noas_{$tid} {$tid} ON core.subject_id={$tid}.subject_id";
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
      return "core.subject_shareable = B'1'";
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
          $sql = "{$conj} core.subject_id IN (SELECT DISTINCT(subject_id) FROM noas_{$tid} t WHERE t.subject_id=core.subject_id AND t.project_id=core.project_id AND t.wave_code=core.wave_code)";
          array_push($r, $sql);
          break;
        case "repeated":
          $sql = "{$conj} core.subject_id IN (SELECT DISTINCT(subject_id) FROM noas_{$tid} t WHERE t.subject_id=core.subject_id AND t.project_id=core.project_id AND t.wave_code=core.wave_code)";
          array_push($r, $sql);
          break;
        case "cross":
          $sql = "{$conj} core.subject_id IN (SELECT DISTINCT(subject_id) FROM noas_{$tid} t WHERE t.subject_id=core.subject_id)";
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
  function _get_repeated_groups($dbmeta, $sel_tabs, $sel_cols){
    $rgroups = array();
    // collect arrays for each group; group_id => [{tab_id, col_id}, ...]
    foreach ($dbmeta->{"tables"} as $t) {
      $tid = $t->{"id"};
      // skip non-included tables
      if (!array_key_exists($tid, $sel_tabs)) {
        continue;
      }
      // if t is not an array, it cannot have repeated group
      // IKA: I think this allways skips/continues, as class is never array?
      //   if (!is_array($t)) {
      //     continue;
      //   }
      // has repeated_goup?
      // echo get_class($t);
      if (!property_exists($t, "repeated_group")) {
        continue;
      }
      // init result?
      $gid = $t->repeated_group->group_id;
      if (!array_key_exists($gid, $rgroups)) {
        $rgroups[$gid] = array();
      }
      $cols = array();
      foreach ($t->{"columns"} as $c){
        $cid = $tid . "_" . $c->{"id"};
        if(array_key_exists($cid , $sel_cols)){
          $cols[] = $cid;
        }
      };

      // add new entry
      $rgroups[$gid][] = array(
        "col_id" => $t->repeated_group->col_id
        ,"table_id" => $tid
        ,"cols" => $cols
      );
    }
    return($rgroups);
  }

  function _get_sql_where_repeated($dbmeta, $sel_tabs, $sel_cols) {
    $rgroups = _get_repeated_groups($dbmeta, $sel_tabs, $sel_cols);
    // generate where conditions; tab0.col=tabn.col
    // IKA: Add WHERE condition AND (... OR ... IS NULL)
    // This fixes cross join issue. Should probably be done in the JOINS, but when code 
    // is structured like it is, easier to do it here. 
    // Probably breaks something else ¯\_(ツ)_/¯
    $sqls = array();
    foreach ($rgroups as $rg) {
      if (count(array_values($rg)) <= 1) {
        continue;
      }
      array_push($sqls, " AND (");
      for ($i=1; $i < count($rg); $i++) {
        array_push($sqls,
          $rg[0 ]["table_id"] . "." . $rg[0 ]["col_id"] .
          " = " . $rg[$i]["table_id"] . "." . $rg[$i]["col_id"]
        );
      };
      // Does this break anything, maybe union/intersection selection option? TODO: test
      for ($i=0; $i < count($rg); $i++) {
        array_push($sqls,
        " OR " . $rg[$i]["table_id"] . "." . $rg[$i]["col_id"] . " IS NULL "
      );
      };
      array_push($sqls,")");
    };
    return join("\n", $sqls);
  }

  function _get_sql_select_repeated($dbmeta, $sel_tabs, $sel_cols) {
    $rgroups = _get_repeated_groups($dbmeta, $sel_tabs, $sel_cols);
    $rcols = [];
    foreach (array_keys($rgroups) as $rg){
      $gid = $rg;
      $tbid = $rgroups[$rg][0]["table_id"];
      $rc = $rgroups[$rg][0]["col_id"];
      $rcols[] = "{$tbid}.{$rc} AS {$gid}_{$rc}";
    }
    return($rcols);
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
  $sql_join   = _get_sql_join($dbmeta, $sel_tabs, $sel->{"set_op"});
  $sql_where  = _get_sql_where($dbmeta, $sel_tabs, $sel->{"set_op"}, $sel->{"project"});
  $sql_where_repeated = _get_sql_where_repeated($dbmeta, $sel_tabs, $sel_cols);

  $sql = "
SELECT DISTINCT
{$sql_select}
FROM noas_core AS core
{$sql_join}
WHERE TRUE AND
{$sql_where}
{$sql_where_repeated}
ORDER BY core.subject_id
";
//   error_log($sql);
  return $sql;
}

?>