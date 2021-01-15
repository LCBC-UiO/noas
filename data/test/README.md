# Mock data for testing

## Core data
### subjects
The test data include 100 unique participants.
Of these, there are in total 20 with non-shareable data, and 20 with `NA` shareable data.

### projects
There are 2 projects, `Proj1` and `Proj2`

### waves
`Proj1` has two waves, and `Proj2` has one.

### visits
There are 160 visits, with 10 data-points missing visit date. 
There are 40 visits in `Proj1` wave `1`, and 68 in wave `2`, and `Proj2` wave 1 has 52 visits. 

### Longitudinal

#### ehi
There are a total of 20 observations in the `ehi` files, of which 10 are omitted upon import for not existing in the visits table (5 per file). 

There is only data for `Proj1`, of which 9 observations are shareable, 1 is non-shareable, and 10 are `NA` shareable. 

#### cvlt
There are a total of 150 observations in the `cvlt` files, none of which are omitted upon import.
There are 100 observations for `Proj1` and 50 for `Proj2`.

26 observations are not shareable, 94 are shareable and 20 are `NA`. 


### Cross-sectional
The test data has a single cross-sectional table, `pgs_ad`.
The table has 40 observations, with 5 observations omitted for not existing in the subjects table.
5 data points are non-shareable, 21 are shareable, and 14 are `NA`.
For `Proj1` 24 observations are available, and 28 for `Proj2`. 

### Repeated
There is a single repeated table in the test-data, the `mri_aparc` table. 
This file has 100 observations, of which 5 are omitted upon import for not existing in the visits table. 
The fourth column identifying repeating within wave observations is `site_name`. 

There are 70 observations for `Proj1` and 25 for `Proj2`. 
62 observations are shareable, 20 are not, and 18 are `NA`.


## Import
![Expected output when `make run_dbimport` is run](readme-exp-imp.png)