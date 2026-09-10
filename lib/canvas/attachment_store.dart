// Selects and exports the platform-specific attachment store implementation.
// Used by canvas startup and media persistence flows.

import 'package:beyond/canvas/attachment_store_base.dart';
import 'package:beyond/canvas/attachment_store_io.dart'
    if (dart.library.js_interop) 'package:beyond/canvas/attachment_store_web.dart';

export 'attachment_store_base.dart';

// ---------- Platform selection ----------

AttachmentStore createAttachmentStore() => PlatformAttachmentStore();
