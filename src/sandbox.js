function onObjectProperty(obj, property, fn) {
    const intervalID = window.setInterval(pollBody, 100);

    function pollBody() {
        if (!obj[property])
            return;

        window.clearInterval(intervalID);
        fn();
    }
}

function onDocumentBody(fn) {
    onObjectProperty(window, 'document', fn);
}

onDocumentBody(function() {
    const frame = document.createElement('iframe');
    document.body.appendChild(frame);
    //  frame.src = "empty.html";


    onObjectProperty(frame.contentWindow, 'document', function() {});
    const doc = frame.contentWindow.document;

    document.foo = 'top doc';
    doc.foo = 'frame doc';

    const script = doc.createElement('script');
    script.type = 'text/javascript';
    script.text =
        'try { \n' +
        '  doc.body.appendChild(script); ' +
        '} catch(e) { ' +
        'alert("caught"); ' +
        '}';

    doc.body.appendChild(script);
});

function makeScriptElement(text) {
}
