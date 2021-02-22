# Mock data for testing

## Core data
### subjects
The test data include 100 unique participants.
Of these, there are in total 20 with non-shareable data, and 20 with `NA` shareable data.

### projects
There are 2 projects, `Proj1` and `Proj2`.

### waves
`Proj1` has two waves, and `Proj2` has one.

### visits
There are 160 visits, with 10 data-points missing visit date.
There are 40 visits in `Proj1` wave `1`, and 68 in wave `2`, and `Proj2` wave 1 has 52 visits.

## Non-core data
### Longitudinal

#### ehi
There are a total of 20 observations in the `ehi` files, of which 10 are omitted upon import for not existing in the visits table (5 per file).

There is only data for `Proj1`, of which 9 observations are shareable, 1 is non-shareable.

#### cvlt
There are a total of 150 observations in the `cvlt` files, none of which are omitted upon import.
There are 100 observations for `Proj1` and 50 for `Proj2`.

26 observations are not shareable, 94 are shareable and 30 are `NA`.


### Cross-sectional
The test data has a single cross-sectional table, `pgs_ad`.
The table has 40 observations, with 5 observations omitted for not existing in the subjects table.
For `Proj1` 24 observations are available, and 28 for `Proj2`.
5 data points are non-shareable, 21 are shareable, and 9 are `NA`.


### Repeated
There are two repeated tables in the test-data, the `mri_aparc` and `mri_aseg` table. 
They both have 100 observations, of which 5 are omitted upon import for not existing in the visits table. 
The fourth column identifying repeating within wave observations is `site_name` for both tables.

There are 70 observations for `Proj1` and 25 for `Proj2`.
60 observations are shareable, 19 are not, and 16 are `NA`.


## Import

Expected output. The order of imported changes may vary, as tables are imported by modification date.

```sh
v       core                           subjects_w1.tsv          (    0/   50 omitted)
v       core                           subjects_w2.tsv          (    0/   50 omitted)
v       core                              projects.tsv          (    0/    2 omitted)
v       core                                 waves.tsv          (    0/    3 omitted)
v       core                             visits_w1.tsv          (    0/   92 omitted)
v       core                             visits_w2.tsv          (    0/   68 omitted)
 ----------
mri_aseg 
v   repeated             mri_aseg         mri_aseg.tsv          (    5/  100 omitted)
v   metadata             mri_aseg                added                               
cvlt 
v       long                 cvlt        MemC_01.0.tsv          (    0/   50 omitted)
v       long                 cvlt        MemP_01.0.tsv          (    0/   50 omitted)
v       long                 cvlt        MemP_02.0.tsv          (    0/   50 omitted)
v   metadata                 cvlt                added                               
mri_aparc 
v   repeated            mri_aparc        mri_aparc.tsv          (    5/  100 omitted)
v   metadata            mri_aparc                added                               
ehi 
v       long                  ehi        MemP_01.0.tsv          (    5/   10 omitted)
v       long                  ehi        MemP_02.0.tsv          (    5/   10 omitted)
v   metadata                  ehi                added                               
pgs_ad 
v      cross               pgs_ad           pgs_ad.tsv          (    5/   40 omitted)
v   metadata               pgs_ad                added                               

 ---------- 
v   Database populated in  0.016 minutes         
```
