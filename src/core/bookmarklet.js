javascript:(function () {
   if (typeof(XMLHttpRequest)  === "undefined") {
     XMLHttpRequest = function() {
       try { return new ActiveXObject("Msxml2.XMLHTTP.6.0"); }
	 catch(e) {}
       try { return new ActiveXObject("Msxml2.XMLHTTP.3.0"); }
	 catch(e) {}
       try { return new ActiveXObject("Msxml2.XMLHTTP"); }
	 catch(e) {}
       try { return new ActiveXObject("Microsoft.XMLHTTP"); }
	 catch(e) {}
       throw new Error("This browser does not support XMLHttpRequest.");
     };
   }

   var r = new XMLHttpRequest();
   var mooskySource = 'http://nujmobile.com/moosky/moosky.js';
   r.open('get', mooskySource, true);
   function stateChange(state) {
     var response = state.currentTarget;
     if (response.readyState == 4) {
       window.alert(response.responseText.length);
       eval(response.responseText);
       window.document.body.appendChild(Moosky.HTML.REPL());
     }
   }
   r.onreadystatechange = stateChange;
   r.send();
})();
   r.overrideMimeType('text/plain');
       document.body.appendChild(document.createTextNode());
       window.alert(response.responseText.length);
res

       eval(response.responseText);
/       document.body.appendChild(Moosky.HTML.REPL());

