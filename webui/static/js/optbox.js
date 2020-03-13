
/* code to toggle option boxes */

function toggleClass(element, className) {
  if (!element || !className){
    return;
  }
  var classString = element.className, nameIndex = classString.indexOf(className);
  if (nameIndex == -1) {
    classString += ' ' + className;
  }
  else {
    classString = classString.substr(0, nameIndex) + classString.substr(nameIndex+className.length);
  }
  element.className = classString;
}

function addToggle(id) {
  document.querySelector("#" + id + " .optopener").addEventListener('click', function() {
    toggleClass(document.querySelector("#" + id + " > .optbody"), 'openoptbody');
    toggleClass(document.querySelector("#" + id + "   .ddarrow"), 'openddarrow');
  });
}

/* register toggle on all boxes */
boxes = document.querySelectorAll(".optbox")
for (let i = 0; i < boxes.length; i++) {
  addToggle(boxes[i].id)
}
