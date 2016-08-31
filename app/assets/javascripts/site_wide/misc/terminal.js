function exportTerminalBuffer() {
  var output = $(".terminal").terminal().get_output();
  output = output.split("[[;;;error]Command").join("Command");
  output = output.split("commands.]").join("commands.");
  output = output.split("&nbsp;").join(" ");
  output = output.split("[[gb;#609AE9;;black]").join("");
  output = output.split("[[gb;#00AA00;black](openstack)]").join("(openstack)");;
  output = output.split("Type 'help' for usage info.]").join("Type 'help' for usage info.")
  output = output.split("&#91;").join("[");
  output = output.split("&#93;").join("]");
  return output;
}

function saveTerminalOutput(filename, text) {
  var pom = document.createElement('a');
  pom.setAttribute('href', 'data:text/plain;charset=utf-8,' + encodeURIComponent(text));
  pom.setAttribute('download', filename);

  if (document.createEvent) {
    var event = document.createEvent('MouseEvents');
    event.initEvent('click', true, true);
    pom.dispatchEvent(event);
  }
  else {
    pom.click();
  }
}

function setPromptProperties() {
  $(".terminal textarea").attr("autocomplete", "off");
  $(".terminal textarea").attr("autocorrect", "off");
  $(".terminal textarea").attr("autocapitalize", "off");
  $(".terminal textarea").attr("spellcheck", "false");
}