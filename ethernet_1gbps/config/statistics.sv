class statistics;
 
  static virtual eth_ui_interface v_uif[bit[47:0]];
 
  //pause
  static int  pause_value [bit[47:0]];
  static bit  pause_flag  [bit [47:0]];
  static bit  pause_update[bit [47:0]];
 
  //pfc
  static int  pfc_value   [bit [47:0]][8];
  static bit  pfc_flag    [bit [47:0]][8];
  static bit  pfc_update  [bit [47:0]][8];
endclass
