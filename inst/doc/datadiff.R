## ----setup, include = FALSE---------------------------------------------------
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>"
)
library(datadiff)

## ----first-comparison---------------------------------------------------------
library(datadiff)

ref <- data.frame(
  id       = 1:4,
  revenue  = c(1000.00, 2000.00, 3000.00, 4000.00),
  category = c("A", "B", "C", "D"),
  active   = c(TRUE, TRUE, FALSE, TRUE)
)

cand <- data.frame(
  id       = 1:4,
  revenue  = c(1000.005, 2000.001, 3000.009, 4000.00),  # tiny differences
  category = c("a", "b", "c", "D"),                      # lowercase
  active   = c(TRUE, TRUE, FALSE, TRUE)
)

## ----first-rules, results = "hide"--------------------------------------------
rules_path <- tempfile(fileext = ".yaml")

write_rules_template(
  ref,
  key                        = "id",
  path                       = rules_path,
  numeric_abs                = 0.01,   # accept differences up to 0.01
  character_case_insensitive = TRUE    # ignore case for all char columns
)

## ----first-result-------------------------------------------------------------
result <- compare_datasets_from_yaml(ref, cand, key = "id", path = rules_path)
result$all_passed

## ----return-structure---------------------------------------------------------
names(result)

## ----coverage-----------------------------------------------------------------
result$coverage

## ----coverage-summary---------------------------------------------------------
result$summary

## ----coverage-fails, eval = FALSE---------------------------------------------
# result$coverage[result$coverage$status == "FAIL", ]

## ----print-report, eval = FALSE-----------------------------------------------
# print(result$reponse)                              # renders the report on demand
# datadiff_report_html(result, file = "report.html") # ...or save it to a file

## ----applied-rules------------------------------------------------------------
result$applied_rules$revenue
result$applied_rules$category

## ----col-presence-------------------------------------------------------------
result$missing_in_candidate
result$extra_in_candidate

## ----failing-rows-------------------------------------------------------------
ref_fail <- data.frame(id = 1:5, value = c(1, 2, 3, 4, 5))
cand_fail <- data.frame(id = 1:5, value = c(1, 2, 99, 4, 99))  # rows 3 and 5 wrong

result_fail <- compare_datasets_from_yaml(ref_fail, cand_fail, key = "id")
result_fail$all_passed

# Rows that failed at least one step
failed_rows <- pointblank::get_sundered_data(result_fail$reponse, type = "fail")
failed_rows

## ----extract-params, eval = FALSE---------------------------------------------
# # Keep only the first 100 failing rows per validation step
# result <- compare_datasets_from_yaml(ref, cand, key = "id",
#                                      get_first_n = 100)
# 
# # Random sample of 50 failing rows per step
# result <- compare_datasets_from_yaml(ref, cand, key = "id",
#                                      sample_n = 50)
# 
# # 10% of failing rows, capped at 500
# result <- compare_datasets_from_yaml(ref, cand, key = "id",
#                                      sample_frac = 0.1, sample_limit = 500)
# 
# # Disable extraction entirely (fastest - only pass/fail counts are kept)
# result <- compare_datasets_from_yaml(ref, cand, key = "id",
#                                      extract_failed = FALSE)

## ----no-yaml------------------------------------------------------------------
ref_quick  <- data.frame(id = 1:3, x = c(1.0, 2.0, 3.0), label = c("A", "B", "C"))
cand_quick <- data.frame(id = 1:3, x = c(1.0, 2.0, 3.0), label = c("A", "B", "C"))

# No path needed - rules are generated on the fly
result_quick <- compare_datasets_from_yaml(ref_quick, cand_quick, key = "id")
result_quick$all_passed

## ----read-rules---------------------------------------------------------------
loaded <- read_rules(rules_path)

loaded$defaults$na_equal
loaded$by_type$numeric
loaded$by_type$character

## ----byname-example-----------------------------------------------------------
ref_full <- data.frame(
  id          = 1:4,
  price       = c(9.99, 19.99, 4.50, 149.00),      # numeric: small absolute tolerance
  quantity    = c(10L, 5L, 20L, 1L),                # integer: exact
  description = c("Widget A", "Widget B", "  Gadget", "TOOL"),  # needs trim + case
  in_stock    = c(TRUE, TRUE, FALSE, TRUE),          # logical: exact
  created     = as.Date(c("2024-01-01", "2024-01-02",
                           "2024-01-03", "2024-01-04"))
)

cand_full <- data.frame(
  id          = 1:4,
  price       = c(9.995, 19.99, 4.50, 149.00),  # row 1: diff = 0.005 < 0.01
  quantity    = c(10L, 5L, 20L, 1L),
  description = c("widget a", "Widget B", "Gadget", "tool"),  # case + spaces
  in_stock    = c(TRUE, TRUE, FALSE, TRUE),
  created     = as.Date(c("2024-01-01", "2024-01-02",
                           "2024-01-03", "2024-01-04"))
)

## ----byname-rules, results = "hide"-------------------------------------------
rules_full <- tempfile(fileext = ".yaml")

write_rules_template(
  ref_full,
  key                        = "id",
  path                       = rules_full,
  numeric_abs                = 1e-9,     # conservative default
  character_case_insensitive = FALSE,    # strict default for character
  character_trim             = FALSE
)

# Read, patch by_name, write back
rules_obj <- read_rules(rules_full)

rules_obj$by_name$price       <- list(abs = 0.01)           # +/-0.01 for price
rules_obj$by_name$description <- list(case_insensitive = TRUE, trim = TRUE)

yaml::write_yaml(rules_obj, rules_full)

## ----byname-result------------------------------------------------------------
result_full <- compare_datasets_from_yaml(ref_full, cand_full,
                                          key = "id", path = rules_full)
result_full$all_passed

# Verify the effective rules for each column
result_full$applied_rules$price
result_full$applied_rules$description
result_full$applied_rules$quantity

## ----abs-tolerance------------------------------------------------------------
ref_num  <- data.frame(id = 1:3, price = c(1.00, 1000.00, 1e6))
cand_ok  <- data.frame(id = 1:3, price = c(1.005, 1000.005, 1e6 + 0.005))
cand_nok <- data.frame(id = 1:3, price = c(1.02,  1000.02,  1e6 + 0.02))

rules_abs <- tempfile(fileext = ".yaml")
write_rules_template(ref_num, key = "id", path = rules_abs, numeric_abs = 0.01)

compare_datasets_from_yaml(ref_num, cand_ok,  key = "id", path = rules_abs)$all_passed
compare_datasets_from_yaml(ref_num, cand_nok, key = "id", path = rules_abs)$all_passed

## ----rel-tolerance------------------------------------------------------------
rules_rel <- tempfile(fileext = ".yaml")
write_rules_template(ref_num, key = "id", path = rules_rel,
                     numeric_abs = 0, numeric_rel = 0.01)

# ref = 1000, diff = 9, threshold = 0.01 * 1000 = 10 -> PASS
cand_pct <- data.frame(id = 1:3, price = c(1.009, 1009.0, 1e6 * 1.009))
compare_datasets_from_yaml(ref_num, cand_pct, key = "id", path = rules_rel)$all_passed

## ----ieee754------------------------------------------------------------------
# In double precision, this is slightly above 0.01
100.01 - 100.00

## ----warn-stop, eval = FALSE--------------------------------------------------
# result <- compare_datasets_from_yaml(
#   ref, cand,
#   key     = "id",
#   warn_at = 0.05,   # warn if > 5% of rows fail any step
#   stop_at = 0.20    # stop (error) if > 20% of rows fail any step
# )

## ----text-comparison----------------------------------------------------------
ref_txt  <- data.frame(id = 1:4, label = c("Hello", "World", "Foo", "Bar"))
cand_txt <- data.frame(
  id    = 1:4,
  label = c("hello", "  World  ", "FOO", "Baz")  # case, spaces, mismatch
)

# Strict: rows 1, 2, 3 fail
rules_strict <- tempfile(fileext = ".yaml")
write_rules_template(ref_txt, key = "id", path = rules_strict)
compare_datasets_from_yaml(ref_txt, cand_txt, key = "id",
                           path = rules_strict)$all_passed

# Relaxed: case + trim - only row 4 ("Baz" vs "Bar") fails
rules_relax <- tempfile(fileext = ".yaml")
write_rules_template(ref_txt, key = "id", path = rules_relax,
                     character_case_insensitive = TRUE,
                     character_trim             = TRUE)
compare_datasets_from_yaml(ref_txt, cand_txt, key = "id",
                           path = rules_relax)$all_passed

## ----row-validation-----------------------------------------------------------
ref_rows  <- data.frame(id = 1:5, value = 1:5)
cand_ok   <- data.frame(id = 1:5, value = 1:5)   # 5 rows - exact match
cand_more <- data.frame(id = 1:7, value = 1:7)   # 7 rows - 2 extra

rules_count <- tempfile(fileext = ".yaml")
write_rules_template(ref_rows, key = "id", path = rules_count,
                     check_count_default         = TRUE,
                     expected_count_default      = 5,
                     row_count_tolerance_default = 0)

compare_datasets_from_yaml(ref_rows, cand_ok,   key = "id",
                           path = rules_count)$all_passed
compare_datasets_from_yaml(ref_rows, cand_more, key = "id",
                           path = rules_count)$all_passed

## ----row-tolerance------------------------------------------------------------
rules_tol <- tempfile(fileext = ".yaml")
write_rules_template(ref_rows, key = "id", path = rules_tol,
                     check_count_default         = TRUE,
                     expected_count_default      = 5,
                     row_count_tolerance_default = 3)  # accept 5 +/- 3

# row_count check PASSES: |7 - 5| = 2 is within tolerance 3.
# all_passed is still FALSE here: the 2 extra keyed rows (id 6, 7) have
# no reference counterpart and fail the per-column value comparison.
compare_datasets_from_yaml(ref_rows, cand_more, key = "id",
                           path = rules_tol)$all_passed

## ----na-handling--------------------------------------------------------------
ref_na  <- data.frame(id = 1:3, value = c(1.0, NA, 3.0))
cand_na <- data.frame(id = 1:3, value = c(1.0, NA, 3.0))  # identical NAs

# na_equal: yes (default) - NA == NA passes
rules_na_yes <- tempfile(fileext = ".yaml")
write_rules_template(ref_na, key = "id", path = rules_na_yes,
                     na_equal_default = TRUE)
compare_datasets_from_yaml(ref_na, cand_na, key = "id",
                           path = rules_na_yes)$all_passed

# na_equal: no - NA == NA fails
rules_na_no <- tempfile(fileext = ".yaml")
write_rules_template(ref_na, key = "id", path = rules_na_no,
                     na_equal_default = FALSE)
compare_datasets_from_yaml(ref_na, cand_na, key = "id",
                           path = rules_na_no)$all_passed

## ----ignore-columns-----------------------------------------------------------
ref_ign  <- data.frame(id = 1:3, value = 1:3, updated_at = Sys.time())
cand_ign <- data.frame(id = 1:3, value = 1:3,
                       updated_at = Sys.time() + 3600)  # different timestamp

rules_ign <- tempfile(fileext = ".yaml")
write_rules_template(ref_ign, key = "id", path = rules_ign,
                     ignore_columns_default = "updated_at")

compare_datasets_from_yaml(ref_ign, cand_ign, key = "id",
                           path = rules_ign)$all_passed

## ----col-analysis-------------------------------------------------------------
ref_cols  <- data.frame(id = 1:2, a = 1:2, b = 1:2)
cand_cols <- data.frame(id = 1:2, a = 1:2, c = 1:2)  # b missing, c extra

result_cols <- compare_datasets_from_yaml(ref_cols, cand_cols, key = "id")
result_cols$missing_in_candidate   # b
result_cols$extra_in_candidate     # c
result_cols$all_passed             # FALSE: b is missing

## ----analyze-columns----------------------------------------------------------
analysis <- analyze_columns(ref_cols, cand_cols,
                            ignore_columns = character(0))
str(analysis)

## ----with-key-----------------------------------------------------------------
ref_key  <- data.frame(id = 1:3, value = c(10, 20, 30))
cand_key <- data.frame(id = c(3, 1, 2), value = c(30, 10, 20))  # shuffled

result_key <- compare_datasets_from_yaml(ref_key, cand_key, key = "id")
result_key$all_passed

## ----positional---------------------------------------------------------------
ref_pos  <- data.frame(value = c(1.0, 2.0, 3.0))
cand_pos <- data.frame(value = c(1.0, 2.0, 3.0))

result_pos <- compare_datasets_from_yaml(ref_pos, cand_pos)
result_pos$all_passed

## ----composite-key------------------------------------------------------------
ref_comp <- data.frame(
  year  = c(2023, 2023, 2024),
  month = c(1, 2, 1),
  value = c(100, 200, 300)
)
cand_comp <- data.frame(
  year  = c(2024, 2023, 2023),
  month = c(1,    2,    1),
  value = c(300,  200,  100)
)

result_comp <- compare_datasets_from_yaml(ref_comp, cand_comp,
                                          key = c("year", "month"))
result_comp$all_passed

## ----key-override, results = "hide"-------------------------------------------
rules_key <- tempfile(fileext = ".yaml")
write_rules_template(ref_comp, key = "year", path = rules_key)  # YAML says year

# Override at call time with the composite key
result_override <- compare_datasets_from_yaml(
  ref_comp, cand_comp,
  key  = c("year", "month"),   # overrides YAML
  path = rules_key
)
result_override$all_passed

## ----duplicate-keys, warning = TRUE-------------------------------------------
ref_dup  <- data.frame(id = c(1, 1, 2), value = c(10, 11, 20))
cand_dup <- data.frame(id = c(1, 2),    value = c(10, 20))

tryCatch(
  compare_datasets_from_yaml(ref_dup, cand_dup, key = "id"),
  warning = function(w) message("Warning: ", conditionMessage(w))
)

## ----type-mismatch, warning = TRUE--------------------------------------------
ref_type  <- data.frame(id = 1:2, year = c(2023L, 2024L))  # integer
cand_type <- data.frame(id = 1:2, year = c("2023", "2024")) # character

tryCatch(
  compare_datasets_from_yaml(ref_type, cand_type, key = "id"),
  warning = function(w) message("Warning: ", conditionMessage(w))
)

## ----detect-types-------------------------------------------------------------
df_types <- data.frame(
  id        = 1L,
  amount    = 1.5,
  label     = "x",
  flag      = TRUE,
  day       = Sys.Date(),
  timestamp = Sys.time()
)

detect_column_types(df_types)

## ----derive-rules-------------------------------------------------------------
rules_obj2 <- read_rules(rules_path)
merged <- derive_column_rules(ref, rules_obj2)
merged$revenue
merged$category

## ----preprocess---------------------------------------------------------------
df_raw <- data.frame(label = c("  Hello ", "WORLD", "  Foo  "))
rules_norm <- list(
  label = list(equal_mode = "normalized",
               case_insensitive = TRUE,
               trim = TRUE)
)
preprocess_dataframe(df_raw, rules_norm)

## ----tolerance-debug----------------------------------------------------------
cmp <- data.frame(
  value            = c(1.005, 1.02, 1.0),
  value__reference = c(1.000, 1.00, 1.0)
)
rules_debug <- list(value = list(abs = 0.01, rel = 0))

cmp_annotated <- add_tolerance_columns(cmp, "value", rules_debug,
                                       ref_suffix = "__reference",
                                       na_equal   = TRUE)
cmp_annotated[, c("value__absdiff", "value__thresh", "value__ok")]

## ----lang-per-call, eval = FALSE----------------------------------------------
# result_fr <- compare_datasets_from_yaml(
#   ref, cand,
#   key    = "id",
#   lang   = "fr",
#   locale = "fr_FR"
# )

## ----lang-global, eval = FALSE------------------------------------------------
# options(datadiff.lang   = "fr",
#         datadiff.locale = "fr_FR")
# 
# # All calls now produce French reports without passing lang/locale every time
# result <- compare_datasets_from_yaml(ref, cand, key = "id", path = rules_path)

## ----lazy-dbplyr, eval = FALSE------------------------------------------------
# library(DBI)
# library(dplyr)
# 
# con <- DBI::dbConnect(RSQLite::SQLite(), ":memory:")
# DBI::dbWriteTable(con, "reference", ref)
# DBI::dbWriteTable(con, "candidate", cand)
# 
# tbl_ref  <- dplyr::tbl(con, "reference")
# tbl_cand <- dplyr::tbl(con, "candidate")
# 
# result_lazy <- compare_datasets_from_yaml(
#   tbl_ref, tbl_cand,
#   key  = "id",
#   path = rules_path
# )
# 
# result_lazy$all_passed
# DBI::dbDisconnect(con)

## ----large-arrow, eval = FALSE------------------------------------------------
# library(arrow)
# 
# ds_ref  <- arrow::open_dataset("path/to/reference/")
# ds_cand <- arrow::open_dataset("path/to/candidate/")
# 
# # Generate a template from the schema (no data loaded into RAM)
# write_rules_template(ds_ref, key = "id", path = "rules.yaml")
# 
# result <- compare_datasets_from_yaml(
#   data_reference      = ds_ref,
#   data_candidate      = ds_cand,
#   key                 = "id",
#   path                = "rules.yaml",
#   duckdb_memory_limit = "8GB"    # tune to your machine's RAM
# )
# 
# result$all_passed

