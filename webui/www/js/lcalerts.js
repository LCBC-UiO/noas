// helper showing bootstrap alerts
// looks for a div with id "alerts"
const AlertType = {
  ERROR:   {id: "error",   bsClass: "alert-danger"},
  OK:      {id: "ok",      bsClass: "alert-success"},
  WARNING: {id: "warning", bsClass: "alert-warning"},
}
function showAlertBox(alertType, msgs) {
  let epar = document.getElementById('alerts');
  let en = document.createElement('div');
  epar.appendChild(en);
  en.classList.add('alert');
  en.classList.add(alertType.bsClass);
  en.classList.add('alert-dismissible');
  en.classList.add('mt-1');
  let ea = document.createElement('a');
  en.appendChild(ea);
  ea.classList.add("close");
  ea.classList.add("p-0");
  ea.setAttribute("data-dismiss", "alert");
  ea.innerHTML = "&times";
  en.insertAdjacentHTML('beforeend', [].concat(msgs).join("<br>"));
}