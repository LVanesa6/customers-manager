function handler(event) {
  var request = event.request;
  var uri = request.uri;
  var lastSegment = uri.split('/').pop();

  if (!lastSegment.includes('.')) {
    request.uri = '/index.html';
  }

  return request;
}
