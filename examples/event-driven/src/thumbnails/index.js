// Runs when an object is finalized in the uploads bucket.
const functions = require('@google-cloud/functions-framework');

functions.cloudEvent('makeThumbnail', (cloudEvent) => {
  const { bucket, name } = cloudEvent.data;
  console.log(`would create a thumbnail of gs://${bucket}/${name} in ${process.env.THUMBNAIL_BUCKET}`);
});
