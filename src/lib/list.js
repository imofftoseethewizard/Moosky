with (Moosky.Top) {
(function () {
   return undefined, 
          $["for-all"] = (function (P) {
                            var Ls = $argumentsList(arguments, 
                                              1), 
                                $loop_1281, 
                                $loop_1277;
                            return ($temp = $["null?"](Ls)) !== false
                                      ? $temp
                                      : $["null?"](car(Ls))
                                           ? ($loop_1277 = undefined, 
                                              $loop_1277 = (function (Ls) {
                                                              var $Ls_1280, 
                                                                  $R_1278, 
                                                                  $C_1279 = Object();
                                                              while (($R_1278 = ($temp = $["null?"](Ls)) !== false
                                                                                   ? $temp
                                                                                   : not($["null?"](car(Ls)))
                                                                                        ? $symbol("&exception")
                                                                                        : ($Ls_1280 = cdr(Ls), 
                                                                                           Ls = $Ls_1280, 
                                                                                           $C_1279)) === $C_1279) ;
                                                              return $R_1278;
                                                            }), 
                                              $loop_1277(cdr(Ls)))
                                           : ($loop_1281 = undefined, 
                                              $loop_1281 = (function (Ls, args, remainders) {
                                                              var $Ls_1285, 
                                                                  $args_1286, 
                                                                  $remainders_1287, 
                                                                  $R_1283, 
                                                                  $C_1284 = Object(), 
                                                                  $L_1288, 
                                                                  $L_1282;
                                                              while (($R_1283 = $["null?"](Ls)
                                                                                   ? (apply(P, 
                                                                                            reverse(args)) === false
                                                                                         ? false
                                                                                         : apply($["for-all"], 
                                                                                                 P, 
                                                                                                 reverse(remainders)))
                                                                                   : ($L_1288 = car(Ls), 
                                                                                      $["null?"]($L_1288)
                                                                                         ? $symbol("&exception")
                                                                                         : ($Ls_1285 = cdr(Ls), 
                                                                                            $args_1286 = cons(car($L_1288), 
                                                                                                              args), 
                                                                                            $remainders_1287 = cons(cdr($L_1288), 
                                                                                                                    remainders), 
                                                                                            Ls = $Ls_1285, 
                                                                                            args = $args_1286, 
                                                                                            remainders = $remainders_1287, 
                                                                                            $C_1284))) === $C_1284) ;
                                                              return $R_1283;
                                                            }), 
                                              $loop_1281(Ls, 
                                                         $nil, 
                                                         $nil));
                          }), 
          undefined, 
          $["exists"] = (function (P) {
                           var Ls = $argumentsList(arguments, 
                                             1);
                           return not(apply($["for-all"], 
                                            function () {
                                              var args = $argumentsList(arguments, 
                                                                  0);
                                              return not(apply(P, 
                                                               args));
                                            }, 
                                            Ls));
                         }), 
          undefined, 
          $["filter"] = (function (P, L) {
                           return $["call-with-values"](partition(P, 
                                                                  L), 
                                                        function ($36let$45values_1273, $36let$45values_1274) {
                                                          var $matches_1289, 
                                                              $misses_1290;
                                                          return $matches_1289 = $36let$45values_1273, 
                                                                 $misses_1290 = $36let$45values_1274, 
                                                                 $matches_1289;
                                                        });
                         }), 
          undefined, 
          $["partition"] = (function (P, L) {
                              var $loop_1291;
                              return $loop_1291 = undefined, 
                                     $loop_1291 = (function (L, matches, misses) {
                                                     var $L_1295, 
                                                         $matches_1296, 
                                                         $misses_1297, 
                                                         $R_1293, 
                                                         $C_1294 = Object(), 
                                                         $head_1298, 
                                                         $head_1292;
                                                     while (($R_1293 = $["null?"](L)
                                                                          ? values(reverse(matches), 
                                                                                   reverse(misses))
                                                                          : ($head_1298 = car(L), 
                                                                             P($head_1298)
                                                                                ? ($L_1295 = cdr(L), 
                                                                                   $matches_1296 = cons($head_1298, 
                                                                                                        matches), 
                                                                                   $misses_1297 = misses, 
                                                                                   L = $L_1295, 
                                                                                   matches = $matches_1296, 
                                                                                   misses = $misses_1297, 
                                                                                   $C_1294)
                                                                                : ($L_1295 = cdr(L), 
                                                                                   $matches_1296 = matches, 
                                                                                   $misses_1297 = cons($head_1298, 
                                                                                                       misses), 
                                                                                   L = $L_1295, 
                                                                                   matches = $matches_1296, 
                                                                                   misses = $misses_1297, 
                                                                                   $C_1294))) === $C_1294) ;
                                                     return $R_1293;
                                                   }), 
                                     $loop_1291(L, 
                                                $nil, 
                                                $nil);
                            }), 
          undefined, 
          $["fold-left"] = (function (combine, nil) {
                              var Ls = $argumentsList(arguments, 
                                                2), 
                                  $loop_1303, 
                                  $loop_1299;
                              return $["null?"](Ls)
                                        ? nil
                                        : ($["null?"](car(Ls))
                                              ? ($loop_1299 = undefined, 
                                                 $loop_1299 = (function (Ls) {
                                                                 var $Ls_1302, 
                                                                     $R_1300, 
                                                                     $C_1301 = Object();
                                                                 while (($R_1300 = $["null?"](Ls)
                                                                                      ? nil
                                                                                      : (not($["null?"](car(Ls)))
                                                                                            ? $symbol("&exception1")
                                                                                            : ($Ls_1302 = cdr(Ls), 
                                                                                               Ls = $Ls_1302, 
                                                                                               $C_1301))) === $C_1301) ;
                                                                 return $R_1300;
                                                               }), 
                                                 $loop_1299(cdr(Ls)))
                                              : ($loop_1303 = undefined, 
                                                 $loop_1303 = (function (Ls, args, remainders) {
                                                                 var $Ls_1307, 
                                                                     $args_1308, 
                                                                     $remainders_1309, 
                                                                     $R_1305, 
                                                                     $C_1306 = Object(), 
                                                                     $L_1310, 
                                                                     $L_1304;
                                                                 while (($R_1305 = $["null?"](Ls)
                                                                                      ? apply($["fold-left"], 
                                                                                              combine, 
                                                                                              apply(combine, 
                                                                                                    nil, 
                                                                                                    reverse(args)), 
                                                                                              reverse(remainders))
                                                                                      : ($L_1310 = car(Ls), 
                                                                                         $["null?"]($L_1310)
                                                                                            ? $symbol("&exception2")
                                                                                            : ($Ls_1307 = cdr(Ls), 
                                                                                               $args_1308 = cons(car($L_1310), 
                                                                                                                 args), 
                                                                                               $remainders_1309 = cons(cdr($L_1310), 
                                                                                                                       remainders), 
                                                                                               Ls = $Ls_1307, 
                                                                                               args = $args_1308, 
                                                                                               remainders = $remainders_1309, 
                                                                                               $C_1306))) === $C_1306) ;
                                                                 return $R_1305;
                                                               }), 
                                                 $loop_1303(Ls, 
                                                            $nil, 
                                                            $nil)));
                            }), 
          undefined, 
          $["fold-right"] = (function (combine, nil) {
                               var Ls = $argumentsList(arguments, 
                                                 2), 
                                   $loop_1315, 
                                   $loop_1311;
                               return $["null?"](Ls)
                                         ? nil
                                         : ($["null?"](car(Ls))
                                               ? ($loop_1311 = undefined, 
                                                  $loop_1311 = (function (Ls) {
                                                                  var $Ls_1314, 
                                                                      $R_1312, 
                                                                      $C_1313 = Object();
                                                                  while (($R_1312 = $["null?"](Ls)
                                                                                       ? nil
                                                                                       : (not($["null?"](car(Ls)))
                                                                                             ? $symbol("&exception3")
                                                                                             : ($Ls_1314 = cdr(Ls), 
                                                                                                Ls = $Ls_1314, 
                                                                                                $C_1313))) === $C_1313) ;
                                                                  return $R_1312;
                                                                }), 
                                                  $loop_1311(cdr(Ls)))
                                               : ($loop_1315 = undefined, 
                                                  $loop_1315 = (function (Ls, args, remainders) {
                                                                  var $Ls_1319, 
                                                                      $args_1320, 
                                                                      $remainders_1321, 
                                                                      $R_1317, 
                                                                      $C_1318 = Object(), 
                                                                      $L_1322, 
                                                                      $L_1316;
                                                                  while (($R_1317 = $["null?"](Ls)
                                                                                       ? apply(combine, 
                                                                                               reverse(cons(apply($["fold-right"], 
                                                                                                                  combine, 
                                                                                                                  nil, 
                                                                                                                  reverse(remainders)), 
                                                                                                            args)))
                                                                                       : ($L_1322 = car(Ls), 
                                                                                          $["null?"]($L_1322)
                                                                                             ? $symbol("&exception")
                                                                                             : ($Ls_1319 = cdr(Ls), 
                                                                                                $args_1320 = cons(car($L_1322), 
                                                                                                                  args), 
                                                                                                $remainders_1321 = cons(cdr($L_1322), 
                                                                                                                        remainders), 
                                                                                                Ls = $Ls_1319, 
                                                                                                args = $args_1320, 
                                                                                                remainders = $remainders_1321, 
                                                                                                $C_1318))) === $C_1318) ;
                                                                  return $R_1317;
                                                                }), 
                                                  $loop_1315(Ls, 
                                                             $nil, 
                                                             $nil)));
                             }), 
          undefined, 
          $["remp"] = (function (P, L) {
                         return $["call-with-values"](partition(P, 
                                                                L), 
                                                      function ($36let$45values_1275, $36let$45values_1276) {
                                                        var $matches_1323, 
                                                            $misses_1324;
                                                        return $matches_1323 = $36let$45values_1275, 
                                                               $misses_1324 = $36let$45values_1276, 
                                                               $misses_1324;
                                                      });
                       }), 
          undefined, 
          $["remove"] = (function (x, L) {
                           return remp(function (a) {
                                         return $["equal?"](a, 
                                                            x);
                                       }, 
                                       L);
                         }), 
          undefined, 
          $["remv"] = (function (x, L) {
                         return remp(function (a) {
                                       return $["eqv?"](a, 
                                                        x);
                                     }, 
                                     L);
                       }), 
          undefined, 
          $["remq"] = (function (x, L) {
                         return remp(function (a) {
                                       return $["eq?"](a, 
                                                       x);
                                     }, 
                                     L);
                       }), 
          undefined, 
          $["memp"] = (function (P, L) {
                         var $P_1327, 
                             $L_1328, 
                             $R_1325, 
                             $C_1326 = Object();
                         while (($R_1325 = $["null?"](L)
                                              ? false
                                              : (P(car(L))
                                                    ? L
                                                    : ($P_1327 = P, 
                                                       $L_1328 = cdr(L), 
                                                       P = $P_1327, 
                                                       L = $L_1328, 
                                                       $C_1326))) === $C_1326) ;
                         return $R_1325;
                       }), 
          undefined, 
          $["member"] = (function (x, L) {
                           return memp(function (a) {
                                         return $["equal?"](a, 
                                                            x);
                                       }, 
                                       L);
                         }), 
          undefined, 
          $["memv"] = (function (x, L) {
                         return memp(function (a) {
                                       return $["eqv?"](a, 
                                                        x);
                                     }, 
                                     L);
                       }), 
          undefined, 
          $["memq"] = (function (x, L) {
                         return memp(function (a) {
                                       return $["eq?"](a, 
                                                       x);
                                     }, 
                                     L);
                       }), 
          undefined, 
          $["assp"] = (function (P, L) {
                         return find(function (pair) {
                                       return P(car(pair));
                                     }, 
                                     L);
                       }), 
          undefined, 
          $["assoc"] = (function (x, L) {
                          return assp(function (a) {
                                        return $["equal?"](a, 
                                                           x);
                                      }, 
                                      L);
                        }), 
          undefined, 
          $["assv"] = (function (x, L) {
                         return assp(function (a) {
                                       return $["eqv?"](a, 
                                                        x);
                                     }, 
                                     L);
                       }), 
          undefined, 
          $["assq"] = (function (x, L) {
                         return assp(function (a) {
                                       return $["eq?"](a, 
                                                       x);
                                     }, 
                                     L);
                       }), 
          undefined, 
          $["find"] = (function (P, L) {
                         var $tail_1329;
                         return $tail_1329 = memp(P, 
                                                  L), 
                                $tail_1329 === false
                                   ? false
                                   : car($tail_1329);
                       }), 
          undefined, 
          $["cons*"] = (function () {
                          var xs = $argumentsList(arguments, 
                                            0);
                          return $["fold-right"](function (L, nil) {
                                                   return $["null?"](nil)
                                                             ? L
                                                             : cons(L, 
                                                                    nil);
                                                 }, 
                                                 $nil, 
                                                 xs);
                        }), 
          undefined, 
          $["mapcdr"] = (function (P) {
                           var Ls = $argumentsList(arguments, 
                                             1), 
                               $loop_1334, 
                               $loop_1330;
                           return $["null?"](Ls)
                                     ? $nil
                                     : ($["null?"](car(Ls))
                                           ? ($loop_1330 = undefined, 
                                              $loop_1330 = (function (Ls) {
                                                              var $Ls_1333, 
                                                                  $R_1331, 
                                                                  $C_1332 = Object();
                                                              while (($R_1331 = $["null?"](Ls)
                                                                                   ? $nil
                                                                                   : (not($["null?"](car(Ls)))
                                                                                         ? $symbol("&exception1")
                                                                                         : ($Ls_1333 = cdr(Ls), 
                                                                                            Ls = $Ls_1333, 
                                                                                            $C_1332))) === $C_1332) ;
                                                              return $R_1331;
                                                            }), 
                                              $loop_1330(cdr(Ls)))
                                           : ($loop_1334 = undefined, 
                                              $loop_1334 = (function (Ls, result) {
                                                              var $Ls_1341, 
                                                                  $result_1342, 
                                                                  $R_1339, 
                                                                  $C_1340 = Object(), 
                                                                  $check$45loop_1343, 
                                                                  $check$45loop_1335;
                                                              while (($R_1339 = $["null?"](car(Ls))
                                                                                   ? ($check$45loop_1343 = undefined, 
                                                                                      $check$45loop_1343 = (function (Ls) {
                                                                                                              var $Ls_1346, 
                                                                                                                  $R_1344, 
                                                                                                                  $C_1345 = Object();
                                                                                                              while (($R_1344 = $["null?"](Ls)
                                                                                                                                   ? reverse(result)
                                                                                                                                   : (not($["null?"](car(Ls)))
                                                                                                                                         ? $symbol("&exception2")
                                                                                                                                         : ($Ls_1346 = cdr(Ls), 
                                                                                                                                            Ls = $Ls_1346, 
                                                                                                                                            $C_1345))) === $C_1345) ;
                                                                                                              return $R_1344;
                                                                                                            }), 
                                                                                      $check$45loop_1343(cdr(Ls)))
                                                                                   : ($Ls_1341 = map(cdr, 
                                                                                                     Ls), 
                                                                                      $result_1342 = cons(apply(P, 
                                                                                                                Ls), 
                                                                                                          result), 
                                                                                      Ls = $Ls_1341, 
                                                                                      result = $result_1342, 
                                                                                      $C_1340)) === $C_1340) ;
                                                              return $R_1339;
                                                            }), 
                                              $loop_1334(Ls, 
                                                         $nil)));
                         });
 })()


}