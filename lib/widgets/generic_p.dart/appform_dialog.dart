import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:queue_management_system/core/app_color.dart';


enum FieldType { text, dropdown, pillSelector, textArea, image }

class FormFieldConfig {
  final String key;
  final String label;
  final FieldType type;
  final String? hint;
  final bool required;
  final List<String>? options;   // Static options for dropdown/pillSelector fields.
  final bool halfWidth;          // true = renders side-by-side with an adjacent halfWidth field.
  final bool isNumeric;          // true = only digits are accepted as input.

  // Used instead of the static "options" list when this field's choices
  // depend on another field's current value (e.g. the "Doctor" dropdown
  // depends on the selected "Department").
  final List<String> Function(Map<String, dynamic> currentValues)? dependentOptions;
  final String? emptyOptionsMessage; //shown when dependentOptions returns []

  const FormFieldConfig({
    required this.key,
    required this.label,
    required this.type,
    this.hint,
    this.required = false,
    this.options,
    this.halfWidth = false,
    this.isNumeric = false,
    this.dependentOptions,
     this.emptyOptionsMessage, 
  });
}

// Generic Form Dialog 
class AppFormDialog extends StatefulWidget {
  final String title;
  final List<FormFieldConfig> fields;
  final String submitLabel;
  final void Function(Map<String, dynamic> values) onSubmit;
  final Map<String, dynamic>? initialValues; // Pre-filled data for edit dialogs.

  const AppFormDialog({
    super.key,
    required this.title,
    required this.fields,
    required this.submitLabel,
    required this.onSubmit,
    this.initialValues,
  });

  @override
  State<AppFormDialog> createState() => _AppFormDialogState();
}

class _AppFormDialogState extends State<AppFormDialog> {
  final Map<String, dynamic> values = {};
  final Map<String, TextEditingController> controllers = {};
  final Map<String, Uint8List?> imageBytes = {}; // Picked image data per image field.
  String? errorMessage; // Shown when a required field is left empty on submit.

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      // If initialValues provides a value for this field, use it (edit mode).
      final hasInitial = widget.initialValues?.containsKey(field.key) ?? false;

      if (field.type == FieldType.dropdown || field.type == FieldType.pillSelector) {
        if (hasInitial) {
          values[field.key] = widget.initialValues![field.key];
        } else if (field.dependentOptions != null) {
          final initialOptions = field.dependentOptions!(values);
          values[field.key] = initialOptions.isNotEmpty ? initialOptions.first : null;
        } else {
          values[field.key] = field.options?.first;
        }
      } else if (field.type == FieldType.image) {
        // In edit mode, preload the existing photo if there is one.
        imageBytes[field.key] = hasInitial ? widget.initialValues![field.key] as Uint8List? : null;
      } else {
        // Text/TextArea fields — seed the controller with initial text if available.
        final initialText = hasInitial ? widget.initialValues![field.key]?.toString() ?? "" : "";
        controllers[field.key] = TextEditingController(text: initialText);
      }
    }
  }

  @override
  void dispose() {
    for (final c in controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

void _handleSubmit() {
  for (final field in widget.fields) {
    if (controllers.containsKey(field.key)) {
      values[field.key] = controllers[field.key]!.text;
    }
    if (field.type == FieldType.image) {
      values[field.key] = imageBytes[field.key];
    }
  }

  final missingLabels = <String>[];
  for (final field in widget.fields) {
    if (!field.required) continue;

    final isTextType = field.type == FieldType.text || field.type == FieldType.textArea;
    if (isTextType) {
      final value = (values[field.key] as String?)?.trim() ?? "";
      if (value.isEmpty) missingLabels.add(field.label);
    } else if (field.type == FieldType.dropdown) {          
      if (values[field.key] == null) missingLabels.add(field.label);
    }
  }

  if (missingLabels.isNotEmpty) {
    setState(() {
      errorMessage = "Please fill: ${missingLabels.join(', ')}";
    });
    return;
  }

  widget.onSubmit(values);
  Navigator.pop(context);
}

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final bool isMobile = screenSize.width < 700; 

   
    final double dialogWidth = isMobile ? screenSize.width * 0.92 : 420; 
    final double dialogMaxHeight = isMobile ? screenSize.height * 0.85 : 640; 

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: isMobile
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 24) 
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(maxHeight: dialogMaxHeight),
        padding: EdgeInsets.all(isMobile ? 18 : 24),
        decoration: BoxDecoration(
          color: AppColors.bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: title + close button.
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    overflow: TextOverflow.ellipsis, 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Icon(Icons.close, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Field list, scrollable so a long form still fits on screen.
            Flexible(
              child: SingleChildScrollView(
                child: _buildFieldsLayout(isMobile: isMobile),
              ),
            ),

            // Validation error — only shown after a failed submit attempt.
            if (errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 13),
              ),
            ],

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(widget.submitLabel,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Lays fields out top-to-bottom, pairing up two consecutive halfWidth
  // fields into a single row on desktop. On mobile, halfWidth fields are
  // stacked full-width instead — a ~170px-wide phone column is too narrow
  // for two side-by-side inputs to stay usable.
  Widget _buildFieldsLayout({required bool isMobile}) {
    final List<Widget> rows = [];
    int i = 0;

    while (i < widget.fields.length) {
      final field = widget.fields[i];

      if (!isMobile && 
          field.halfWidth &&
          i + 1 < widget.fields.length &&
          widget.fields[i + 1].halfWidth) {
        rows.add(Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildField(field)),
            const SizedBox(width: 16),
            Expanded(child: _buildField(widget.fields[i + 1])),
          ],
        ));
        i += 2;
      } else {
        rows.add(_buildField(field));
        i += 1;
      }
      rows.add(const SizedBox(height: 18));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: rows);
  }


  Widget _buildField(FormFieldConfig field) {
    switch (field.type) {
      case FieldType.text:
        return _buildTextField(field);
      case FieldType.textArea:
        return _buildTextField(field, maxLines: 3);
      case FieldType.dropdown:
        return _buildDropdownField(field);
      case FieldType.pillSelector:
        return _buildPillSelector(field);
      case FieldType.image:
        return _buildImagePicker(field);
    }
  }

  // Field label, with a red asterisk appended when the field is required.
  Widget _fieldLabel(FormFieldConfig field) {
    return RichText(
      text: TextSpan(
        text: field.label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.grey.shade600,
          letterSpacing: 0.3,
        ),
        children: field.required
            ? [const TextSpan(text: " *", style: TextStyle(color: Colors.redAccent))]
            : [],
      ),
    );
  }

  Widget _buildTextField(FormFieldConfig field, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(field),
        const SizedBox(height: 6),
        TextField(
          controller: controllers[field.key],
          maxLines: maxLines,
          keyboardType: field.isNumeric ? TextInputType.number : TextInputType.text,
          inputFormatters: field.isNumeric
              ? [FilteringTextInputFormatter.digitsOnly] // Only 0-9 gets through.
              : null,
          decoration: InputDecoration(
            hintText: field.hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        ),
      ],
    );
  }

Widget _buildDropdownField(FormFieldConfig field) {
  final List<String> currentOptions =
      field.dependentOptions != null ? field.dependentOptions!(values) : (field.options ?? []);

  if (currentOptions.isNotEmpty && !currentOptions.contains(values[field.key])) {
    values[field.key] = currentOptions.first;
  } else if (currentOptions.isEmpty) {
    values[field.key] = null; 
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _fieldLabel(field),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: currentOptions.isEmpty ? Colors.orange.shade300 : Colors.grey.shade300, 
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: currentOptions.isEmpty ? null : values[field.key],
            isExpanded: true,
            hint: currentOptions.isEmpty
                ? Text(
                    field.emptyOptionsMessage ?? "No options available",  
                    style: TextStyle(color: Colors.orange.shade700, fontSize: 13),
                  )
                : null,
            items: currentOptions.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
            onChanged: currentOptions.isEmpty ? null : (v) => setState(() => values[field.key] = v),
          ),
        ),
      ),
    ],
  );
}

  // Two-option toggle (e.g. Active/Inactive, Available/Unavailable),
  // rendered as side-by-side selectable pills.
  Widget _buildPillSelector(FormFieldConfig field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(field),
        const SizedBox(height: 8),
        Row(
          children: field.options!.map((option) {
            final bool isSelected = values[field.key] == option;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: option != field.options!.last ? 12 : 0),
                child: GestureDetector(
                  onTap: () => setState(() => values[field.key] = option),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFFD4EDDA) : Colors.white,
                      border: Border.all(
                        color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isSelected ? Icons.check_circle : Icons.circle_outlined,
                          size: 18,
                          color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade400,
                        ),
                        const SizedBox(width: 8),
                        Flexible( 
                          child: Text(
                            option,
                            overflow: TextOverflow.ellipsis, 
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // Circular image picker — tapping it opens the gallery, and the
  // picked image is stored as raw bytes (compressed to max 600px wide
  // before reading) rather than a file path.
  Widget _buildImagePicker(FormFieldConfig field) {
    final Uint8List? currentBytes = imageBytes[field.key];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(field),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () async {
            final picker = ImagePicker();
            final pickedFile = await picker.pickImage(
              source: ImageSource.gallery,
              maxWidth: 600, // Compress before storing.
            );
            if (pickedFile == null) return;

            final bytes = await pickedFile.readAsBytes();
            setState(() {
              imageBytes[field.key] = bytes;
            });
          },
          child: Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey.shade100,
              border: Border.all(color: Colors.grey.shade300),
              image: currentBytes != null
                  ? DecorationImage(image: MemoryImage(currentBytes), fit: BoxFit.cover)
                  : null,
            ),
            child: currentBytes == null
                ? Icon(Icons.camera_alt_outlined, color: Colors.grey.shade400, size: 28)
                : null,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          currentBytes == null ? "Tap to upload photo" : "Tap to change photo",
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }
}