/* open the first table (list of participants) */
toggleClass(document.querySelector("#core    > .optbody"), 'openoptbody');
toggleClass(document.querySelector("#core      .ddarrow"), 'openddarrow');
toggleClass(document.querySelector("#options > .optbody"), 'openoptbody');
toggleClass(document.querySelector("#options   .ddarrow"), 'openddarrow');

/*----------------------------------------------------------------------------*/

function summitLogin(e) {
  document.querySelector("form").submit();
}
document.querySelector("#submit").addEventListener('click', summitLogin)
