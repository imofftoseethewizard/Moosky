function observe(element, eventName, handler) {
  if (element.addEventListener) {
    element.addEventListener(eventName, handler, false);
  } else {
      element.attachEvent("on" + eventName, handler);
  }
}

window.setTimeout(function () {
		    var textArea = document.getElementById('id_textarea');
		    observe(textArea, 'change',
			    function() {
			      console.log(Moosky.Values.Cons.printSexp(Moosky(textArea.value)));
			    });
		  }, 500);


