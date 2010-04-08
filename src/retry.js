(function () {
   var $E = Moosky.Top;
   var result = (($E["tail-test"] = ((function () {
					    var $E = this;
					        return function () {
						    $E.n = arguments[0];
						    var result = console.log($E.n), (($_0 = (function () {
											           return $E["negative?"]($E.n);
											       }), ($_0.$bounce = true), $_0) != false  ? (($E.$quoted[0])) : (($_2 = (function () {
																					     return $E["tail-test"](($_1 = (function () {
																									          return $E["-"]($E.n, 1);
																									      }), ($_1.$bounce = true), $_1));
																					 }), ($_2.$bounce = true), $_2)));
						    while (result && result.$bounce)
						          result = result();
						    return result;
						  }
					  }).call($E.$makeFrame($E)))), undefined);
     while (result && result.$bounce)
           result = result();
     return result;
   })();