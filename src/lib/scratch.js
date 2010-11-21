(function () {
   return undefined, 
          $["for-all"] = (function (proc) {
                            var lists = $arglist(arguments, 
                                                 1), 
                                $loop_1287, 
                                $loop_1283;
                            return ($temp = $["null?"](lists)) !== false
                                      ? $temp
                                      : $["null?"](car(lists))
                                           ? ($loop_1283 = undefined, 
                                              $loop_1283 = (function (lists) {
                                                              var $lists_1286, 
                                                                  $R_1284, 
                                                                  $C_1285 = Object();
                                                              while (($R_1284 = ($temp = $["null?"](lists)) !== false
                                                                                   ? $temp
                                                                                   : not($["null?"](car(lists)))
                                                                                        ? $symbol("&exception")
                                                                                        : ($lists_1286 = cdr(lists), 
                                                                                           lists = $lists_1286, 
                                                                                           $C_1285)) === $C_1285) ;
                                                              return $R_1284;
                                                            }), 
                                              $loop_1283(cdr(lists)))
                                           : ($loop_1287 = undefined, 
                                              $loop_1287 = (function (lists, 
                                                                      args, 
                                                                      remainders) {
                                                              var $lists_1291, 
                                                                  $args_1292, 
                                                                  $remainders_1293, 
                                                                  $R_1289, 
                                                                  $C_1290 = Object(), 
                                                                  $lst_1294, 
                                                                  $lst_1288;
                                                              while (($R_1289 = $["null?"](lists)
                                                                                   ? (apply(proc, 
                                                                                            reverse(args)) === false
                                                                                         ? false
                                                                                         : apply($["for-all"], 
                                                                                                 proc, 
                                                                                                 reverse(remainders)))
                                                                                   : ($lst_1294 = car(lists), 
                                                                                      $["null?"]($lst_1294)
                                                                                         ? $symbol("&exception")
                                                                                         : ($lists_1291 = cdr(lists), 
                                                                                            $args_1292 = cons(car($lst_1294), 
                                                                                                              args), 
                                                                                            $remainders_1293 = cons(cdr($lst_1294), 
                                                                                                                    remainders), 
                                                                                            lists = $lists_1291, 
                                                                                            args = $args_1292, 
                                                                                            remainders = $remainders_1293, 
                                                                                            $C_1290))) === $C_1290) ;
                                                              return $R_1289;
                                                            }), 
                                              $loop_1287(lists, 
                                                         $nil, 
                                                         $nil));
                          });
 })()
