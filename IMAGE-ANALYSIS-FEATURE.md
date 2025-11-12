# Image Analysis Feature

## Overview
Added AI-powered image analysis to improve the quality of Reddit post responses. When a Reddit post contains an image, the system now analyzes it using GPT-4o's vision capabilities and incorporates that analysis into the draft composition.

## Problem Solved
Previously, if a Reddit post included an image (screenshot, diagram, error message, etc.), we were only analyzing the text content. This meant we were missing critical context that could help us provide better, more relevant advice.

## Implementation Details

### 1. State Changes (`graph/state.py`)
Added two new fields to `GenerateState`:
- `thread_image_url: Optional[str]` - Stores the URL of the image if present
- `thread_image_analysis: Optional[str]` - Stores the AI-generated analysis of the image

### 2. Image Detection (`graph/nodes/rank_threads.py`)
Enhanced the thread ranking node to detect images in Reddit posts:
- Checks if the post is not a self-post (`is_self == False`)
- Validates that the URL points to an image (by extension or domain)
- Supported formats: `.jpg`, `.jpeg`, `.png`, `.gif`, `.webp`
- Supported domains: `i.redd.it`, `i.imgur.com`, `imgur.com/a/`
- Stores the image URL in state for later analysis

### 3. Vision Analysis (`llm/client.py`)
Added new `analyze_image()` method to the LLM client:
- Uses GPT-5 mini (which has vision capabilities)
- Analyzes images with "high" detail level for better accuracy
- Returns concise 2-4 sentence analysis focusing on:
  - What the image shows (objects, text, diagrams, screenshots)
  - Visible issues or problems
  - Technical details (error messages, code, configuration)
  - Context useful for providing advice
- Gracefully handles errors by returning a fallback message

### 4. Draft Composition Integration (`graph/nodes/draft_compose.py`)
Updated the draft composition node to:
- Call `analyze_image()` when `thread_image_url` is present
- Cache the analysis in state (`thread_image_analysis`) to avoid re-analyzing on retries
- Pass the image analysis to the draft composition method
- Log image analysis for debugging

### 5. Prompt Enhancement (`llm/client.py` - `compose_draft()`)
Updated the draft composition prompt to include image analysis:
- Added `image_analysis` parameter to `compose_draft()` method
- Includes image analysis in the prompt under "Image in Post:" section
- Placed strategically after thread body for natural context flow

## Usage Flow

1. **Thread Selection**: When ranking threads, system detects if a thread has an image
2. **Image Analysis**: Before composing draft, system analyzes the image using GPT-4o vision
3. **Draft Composition**: Image analysis is included in the prompt context
4. **Better Responses**: AI can now reference what's in the image when composing helpful replies

## Example Scenarios

### Scenario 1: Error Screenshot
- **Post**: "Getting this error, what does it mean?" + screenshot
- **Image Analysis**: "The image shows a Python traceback error with 'ModuleNotFoundError: No module named flask'. The error occurs at line 3 of app.py when trying to import flask."
- **Result**: Draft can specifically address the missing Flask installation

### Scenario 2: Configuration Question
- **Post**: "Is this setup correct?" + diagram
- **Image Analysis**: "The image shows a network diagram with a load balancer connected to two web servers, but no database server is visible in the architecture."
- **Result**: Draft can point out the missing database component

### Scenario 3: Hardware Issue
- **Post**: "Why is my build not working?" + photo
- **Image Analysis**: "The image shows a PC motherboard with RAM sticks installed in slots 1 and 2. The motherboard manual visible in the background indicates these should be in slots 2 and 4 for dual-channel."
- **Result**: Draft can explain the RAM slot configuration issue

## Performance Considerations

- **Caching**: Image analysis is performed once and cached in state, so retries don't re-analyze
- **Model Choice**: Uses GPT-5 mini for vision, keeping the entire pipeline on a single model
- **Error Handling**: If image analysis fails, system continues with text-only analysis
- **Token Usage**: Image analysis adds ~500 tokens but significantly improves response quality

## Benefits

1. **More Accurate Responses**: Can address issues shown in images, not just described in text
2. **Better Context**: Understands technical details like error messages, code snippets, configurations
3. **Improved Helpfulness**: Can reference specific elements visible in images
4. **Competitive Advantage**: Most Reddit bots don't analyze images, making our responses stand out

## Testing

To test the feature:
1. Find or create a Reddit post with an image (especially technical screenshots)
2. Run the generation workflow for that post
3. Check logs for "Analyzing image:" and "Image analysis:" messages
4. Verify the draft references details from the image
5. Confirm the response is more helpful than text-only analysis would be

## Future Enhancements

Potential improvements for future iterations:
- Support for multiple images in a single post
- Image quality scoring to skip low-quality/irrelevant images
- More specialized image analysis for different content types (code, diagrams, UI, hardware)
- OCR enhancement for text-heavy images
- Support for video thumbnails or GIFs

