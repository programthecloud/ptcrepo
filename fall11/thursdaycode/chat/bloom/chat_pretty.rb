# format chat messages with color and timestamp on the right of the screen
def pretty_print(val)
  str = "\033[7m\033[33m"+val[1].to_s + ":\033[27m " + "\033[37m" + (val[3].to_s || '') + "\033[0m"
  pad = "(" + val[2].to_s + ")"
  return str + " "*[66 - str.length,2].max + pad
end

# format error messages with color and timestamp on the right of the screen
def pretty_notice(val, status)
  str = "\033[32m" + val[0].to_s + ": " + (val[1].to_s || '') + "\033[0m" + " " + status.to_s
  pad = "(" +Time.new.strftime("%I:%M.%S").to_s + ")"
  return str + " "*[61 - str.length,2].max + pad
end