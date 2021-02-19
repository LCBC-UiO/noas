# use stdout only for return values
stopifnot("digest" %in% installed.packages())

#-------------------------------------------------------------------------------

decrypt_from_raw <- function(r_enc) {
  if(! "digest" %in% installed.packages()) {
    stop("please install the \"digest\" package first - cmd: install.packages(\"digest\")")
  }
  key32 <- digest::digest(readline("password:"), algo="sha256", raw=TRUE)
  # split iv from enc data
  r_iv16 <- head(r_enc, n=16)
  r_enc  <- tail(r_enc, n=-16)
  # split hash
  r_hash32 <- head(r_enc, n=32)
  r_enc    <- tail(r_enc, n=-32)
  if (any(digest::hmac(key32, r_enc, "sha256", raw=TRUE) != r_hash32)) {
    stop("mismatching message authentication code: did you enter the correct password?")
  }
  # decrypt
  aes <- digest::AES(key32, mode="CBC", IV=r_iv16)
  r_dec <- aes$decrypt(r_enc, raw=TRUE)
  # unpad data
  s_dump <- rawToChar(r_dec[r_dec>0])
  # source decrypted dump
  zz <- textConnection(s_dump)
  source(zz)
  close(zz)
}

#-------------------------------------------------------------------------------

encrypt_to_source <- function(objects, password=NULL, key32=NULL, 
    fn_out, on_decrypt=function(){cat("decryption successful\n")}, envir=parent.frame()) {
  if (is.null(password) && is.null(key32)) {
    # no key or pw ? -> generate pw
    password <- generate_pw()
    cat(sprintf("The password is \"%s\"\n", password))
  }
  if (!is.null(password)) {
    key32 <- digest::digest(password, algo="sha256", raw=TRUE)
  }
  iv16 <- sample(0:255, 16, replace=TRUE)
  # create str from objects
  zz <- textConnection("s_dump", "w")
  dump(objects, file=zz, envir=envir)
  close(zz)
  r_dec <- charToRaw(paste(s_dump, collapse="\n"))
  # pad data
  r_dec <- c(r_dec, as.raw(rep(0, 16-length(r_dec) %% 16)))
  aes <- digest::AES(key32, mode="CBC", IV=iv16)
  # encrypt
  r_enc <- aes$encrypt(r_dec)
  # get hash
  r_hash32 <- digest::hmac(key32, r_enc, "sha256", raw=TRUE)
  # dump enc with iv and hash
  r_enc <- c(as.raw(iv16), r_hash32, r_enc)
  dump("r_enc", file=fn_out)
  dump("decrypt_from_raw", file=fn_out, append=TRUE)
  dump("on_decrypt", file=fn_out, append=TRUE)
  # decrypt
  write(sprintf("decrypt_from_raw(r_enc)"), file=fn_out, append=TRUE)
  if (!is.null(on_decrypt)) {
    # callback
    write(sprintf("on_decrypt()"), file=fn_out, append=TRUE)
  }
  # cleanup
  write(sprintf('rm("r_enc","decrypt_from_raw","on_decrypt")'), file=fn_out, append=TRUE)
  invisible(password)
}

#-------------------------------------------------------------------------------

key32 <- digest::digest(password, algo="sha256", raw=T)
.noas_objects <- c(".noas_objects", "d_noas", "noas_selection")
# write encryted file
encrypt_to_source(
  objects=.noas_objects,
  key=key32,
  fn_out="",
  # run some function on the data at the end
  on_decrypt=function() {
    cat("\nDecryption successful!\n")
    cat("These objects have been written to your workspace:\n")
    cat("  ");
    # list objects, but skip ".noas_objects" object
    cat(paste(sprintf('"%s"', .noas_objects[-1]), collapse=", "));
    # rm "objects" object
    rm(".noas_objects", envir=parent.frame())
    cat("\n");
  }
)
