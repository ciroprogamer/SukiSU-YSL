find fs/ security/ kernel -type f -exec awk '
  # Maintain a rolling 2-line buffer for "before" context
  {
    b2 = b1; b1 = $0 
  }
  
  # When the start pattern is found
  /ifdef CONFIG_KSU/ {
    print "--- " FILENAME " ---"
    if (NR > 2) print b2
    if (NR > 1) print b1
    
    # Stay in this loop until #endif is found
    while (getline > 0) {
      print $0
      if ($0 ~ /#endif/) break
    }
    
    # Grab 2 lines of "after" context
    for (i=0; i<2; i++) {
      if (getline > 0) print $0
    }
    print "" # Empty line separator
  }
' {} +
