// Creates the browser attachment store used by media persistence flows.
// Used by canvas startup and media persistence flows.

import 'package:elseplane/canvas/persistence/attachments/store_base.dart';
import 'package:elseplane/canvas/persistence/attachments/store_web.dart';

export 'store_base.dart';

// ---------- Store creation ----------

AttachmentStore createAttachmentStore() => PlatformAttachmentStore();
