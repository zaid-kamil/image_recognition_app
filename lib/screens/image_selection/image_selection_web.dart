import 'package:flutter/material.dart';
import 'package:huggingface_client/huggingface_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_picker_for_web/image_picker_for_web.dart';

// Replace with your own API keys
const inferenceApiKey = 'YOUR_API_KEY';

class ImageSelectionWeb extends StatefulWidget {
  const ImageSelectionWeb({super.key});

  @override
  State<ImageSelectionWeb> createState() => _ImageSelectionWebState();
}

enum RecognitionState { idle, loading, success, error }

class _ImageSelectionWebState extends State<ImageSelectionWeb> {
  XFile imageFile = XFile('');
  var isImageSelected = false;
  var recognitionState = RecognitionState.idle;
  var recognitionResults = <String, double>{};

  Future<void> pickImage() async {
    final ImagePickerPlugin imagePicker = ImagePickerPlugin();
    final pickedFile =
        await imagePicker.getImageFromSource(source: ImageSource.gallery);
    setState(() {
      if (pickedFile != null) {
        imageFile = pickedFile;
        isImageSelected = true;
      } else {
        isImageSelected = false;
      }
    });
  }

  void resetImage() {
    setState(() {
      imageFile = XFile('');
      isImageSelected = false;
      recognitionResults = <String, double>{};
      recognitionState = RecognitionState.idle;
    });
  }

  Future<void> recognizeImage() async {
    setState(() {
      recognitionState = RecognitionState.loading;
    });
    final client = HuggingFaceClient.getInferenceClient(
      inferenceApiKey,
      HuggingFaceClient.inferenceBasePath,
    );
    final apiInstance = InferenceApi(client);
    final imageFileContent = await imageFile.readAsBytes();
    imageFileContent.buffer.asByteData();
    try {
      final result = await apiInstance.queryVisionImageClassification(
        imageFile: imageFileContent,
        model: 'google/vit-base-patch16-224',
      );
      if (result!.isNotEmpty) {
        // Map the result to a dictionary
        setState(() {
          for (final item in result) {
            recognitionResults[item!.label] = item.score;
          }
        });
        print('Recognition results: $recognitionResults\n');
      } else {
        // Reset the recognition results
        recognitionResults = <String, double>{};
      }
      setState(() {
        recognitionState = RecognitionState.success;
      });
    } catch (e) {
      print('Exception when calling InferenceApi->inferenceImage: $e\n');
      setState(() {
        recognitionState = RecognitionState.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(16.0),
          child: SelectWidgetFromState(
            isImageSelected: isImageSelected,
            imageFile: imageFile,
            recognitionResults: recognitionResults,
            recognitionState: recognitionState,
            onPickImage: pickImage,
            onResetImage: resetImage,
            onRecognizeImage: recognizeImage,
          ),
        ),
      ),
    );
  }
}

class SelectWidgetFromState extends StatelessWidget {
  const SelectWidgetFromState({
    super.key,
    required this.isImageSelected,
    required this.imageFile,
    required this.recognitionResults,
    required this.recognitionState,
    required this.onPickImage,
    required this.onResetImage,
    required this.onRecognizeImage,
  });

  final bool isImageSelected;
  final XFile imageFile;
  final Map<String, double> recognitionResults;
  final RecognitionState recognitionState;
  final VoidCallback onPickImage, onResetImage, onRecognizeImage;

  @override
  Widget build(BuildContext context) {
    if (isImageSelected) {
      return SingleChildScrollView(
        child: FractionallySizedBox(
          widthFactor: .75,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 512,
                          height: 512,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            boxShadow: const [
                              BoxShadow(
                                spreadRadius: 1,
                                color: Colors.black,
                                blurRadius: 2,
                              )
                            ],
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                          child: ClipRRect(
                              borderRadius: BorderRadius.circular(8.0),
                              child: Image.network(
                                imageFile.path,
                                fit: BoxFit.cover,
                              )),
                        ),
                        // clear image button
                        Positioned(
                          top: 5,
                          right: 5,
                          child: IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: onResetImage,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16.0),
                    Text("Image selected: ${imageFile.name}"),
                    const SizedBox(height: 16.0),
                    FilledButton.icon(
                      onPressed: onRecognizeImage,
                      icon: const Icon(Icons.image_search),
                      label: const Text("Recognize Contents"),
                    )
                  ],
                ),
              ),
              const SizedBox(width: 16.0),
              Expanded(
                child: Column(
                  children: [
                    if (recognitionState == RecognitionState.loading)
                      const CircularProgressIndicator()
                    else if (recognitionState == RecognitionState.success)
                      Column(
                        children: recognitionResults.entries
                            .map(
                              (entry) => ListTile(
                                title: Text(entry.key,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16.0)),
                                subtitle: Text(
                                    'Score: ${(entry.value * 100).toStringAsFixed(2)}%'),
                                leading: entry.value > .7
                                    ? const Icon(
                                        Icons.image_outlined,
                                      )
                                    : const Icon(
                                        Icons.image,
                                      ),
                              ),
                            )
                            .toList(),
                      )
                    else if (recognitionState == RecognitionState.error)
                      const Text('Error recognizing image'),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    } else {
      return UploadImage(onPickImage: onPickImage);
    }
  }
}

class UploadImage extends StatelessWidget {
  const UploadImage({
    super.key,
    required this.onPickImage,
  });

  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      heightFactor: .5,
      child: Column(
        children: [
          const Text(
            'Image Recognition App',
            style: TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.yellow,
                shadows: [
                  BoxShadow(spreadRadius: 3, color: Colors.black, blurRadius: 2)
                ]),
          ),
          const SizedBox(height: 16),
          const Text('No image selected'),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: const ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.orange),
              foregroundColor: WidgetStatePropertyAll(Colors.white),
              padding: WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              ),
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
            ),
            icon: const Icon(Icons.upload),
            onPressed: onPickImage,
            label: const Text('Select Image'),
          ),
        ],
      ),
    );
  }
}
