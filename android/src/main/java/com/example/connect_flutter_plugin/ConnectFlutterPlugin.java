package com.example.connect_flutter_plugin;

import static com.example.connect_flutter_plugin.ScreenUtil.screenSnapshot;
import static com.tl.uic.util.ValueUtil.compareAccessibilityListAndMask;

import android.app.Activity;
import android.app.Application;
import android.content.res.TypedArray;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.graphics.Rect;
import android.os.Build;
import android.text.TextPaint;
import android.text.TextUtils;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewGroup;
import android.webkit.WebView;

import androidx.annotation.NonNull;

import com.acoustic.connect.android.connectmod.Connect;
import com.ibm.eo.EOCore;
import com.ibm.eo.model.EOMonitoringLevel;
import com.ibm.eo.util.ImageUtil;
import com.ibm.eo.util.LogInternal;
import com.tl.uic.TLFCache;
import com.tl.uic.TealeafEOLifecycleObject;
import com.tl.uic.model.BaseTarget;
import com.tl.uic.model.Connection;
import com.tl.uic.model.EventInfo;
import com.tl.uic.model.Gesture;
import com.tl.uic.model.GestureControl;
import com.tl.uic.model.GestureControlPosition;
import com.tl.uic.model.IdType;
import com.tl.uic.model.Image;
import com.tl.uic.model.Layout;
import com.tl.uic.model.LayoutPlaceHolder;
import com.tl.uic.model.Position;
import com.tl.uic.model.PropertyName;
import com.tl.uic.model.ScreenviewType;
import com.tl.uic.model.Style;
import com.tl.uic.model.Touch;
import com.tl.uic.model.TouchPosition;
import com.tl.uic.model.kotlin.Accessibility;
import com.tl.uic.model.kotlin.TLFPerformanceNavigationType;
import com.tl.uic.util.EnhancedImageUtil;
import com.tl.uic.util.LayoutUtil;
import com.tl.uic.util.ValueUtil;

import org.json.JSONObject;

import java.io.ByteArrayOutputStream;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.logging.Level;
import java.util.logging.Logger;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.embedding.engine.renderer.FlutterRenderer;
import io.flutter.embedding.engine.renderer.FlutterUiDisplayListener;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

// TBD: Document code!
// TBD: Check all code warnings!
// TBD: There are several historical/currently unused classes/functions
// at the start of this file. These need to be moved out of this file and
// possibly be deleted soon if no longer needed. This only applies to "un-referenced"
// items.
// --- Start of (possibly some) code to be moved out.

class ScreenUtil {
    private final static boolean dumpFile = false;
    private final static boolean dumpImage = false;
    private final static int imageItems = 6;

    static byte[] obscureAndCompress(Bitmap bitmap, List<Position> maskedPositions) {
        try {
            final Bitmap finalBitmap = maskedPositions.isEmpty() ? bitmap : obscureScreenshot(maskedPositions, bitmap);
            final byte[] snapshot = compress(finalBitmap);

            finalBitmap.recycle();

            return snapshot;
        } catch (Throwable t) {
            LogInternal.logException(TealeafEOLifecycleObject.getInstance().name(), t);
            return null;
        }
    }

    static void saveScreenImage(String md5, byte[] imageBytes) {
        if (dumpFile) {
            final int fileSize = imageBytes.length;
            final String fileName = "ss-" + md5 + "." + EnhancedImageUtil.getImageType();

            ConnectFlutterPlugin.LOGGER.log(Level.INFO, "screenshot name: " + fileName +
                    ", file size: " + fileSize);

            if (fileSize != 0) {
                FileUtil.saveImage(fileName, imageBytes);
            }
        }
    }

    /**
     * Take a screenshot using Flutter renderer.  Note:  getBitmap() requires UI thread.
     * 
     * @param activity
     * @param renderer
     * @return Bitmap.
     */
    static Bitmap screenSnapshot(Activity activity, Object renderer) throws InterruptedException {
        final View view = activity.getWindow().getDecorView().getRootView();
        final Bitmap[] bitmap = new Bitmap[1];
        final CountDownLatch latch = new CountDownLatch(1);

        // Ensure there's delay to allow async to finish drawing on the screen.  0 delay for Gesture.
        Thread.sleep(GestureUtil.isFlutterGestureEvent ? 0 : 500 );

        activity.runOnUiThread(() -> {
            view.setDrawingCacheEnabled(true);

            if (renderer.getClass() == FlutterRenderer.class) {
                bitmap[0] = ((FlutterRenderer) renderer).getBitmap();
            }

            view.setDrawingCacheEnabled(false);
            latch.countDown(); // Signal that the bitmap is ready
        });

        try {
            latch.await(); // Wait for the bitmap to be captured
        } catch (InterruptedException e) {
            e.printStackTrace();
        }

        return bitmap[0];
    }

    static byte[] compress(final Bitmap bitmap) {
        byte[] compressed = null;

        try {
            final ByteArrayOutputStream stream = ImageUtil.compressImage(bitmap, "compressedFlutter",
                    EnhancedImageUtil.getPercentOfScreenshotsSize(), EnhancedImageUtil.getPercentToCompressImage(),
                    EnhancedImageUtil.getCompressFormat());

            if (stream != null) {
                compressed = stream.toByteArray();
                stream.close();
            }
        } catch (Throwable t) {
            LogInternal.logException(TealeafEOLifecycleObject.getInstance().name(), t);
        }

        return compressed;
    }

    /**
     * Use positions data for screen masking.
     *
     * @param positionList
     * @param bitmap
     * @return Masked screenshot Bitmap.
     */
    static Bitmap obscureScreenshot(List<Position> positionList, Bitmap bitmap) {
        Bitmap mutableBitmap = bitmap.copy(Bitmap.Config.ARGB_8888, true);
        final Canvas canvasFinal = new Canvas(mutableBitmap);

        final TextPaint paint = new TextPaint();
        paint.setColor(Color.WHITE);
        paint.bgColor = Color.BLACK;
        paint.setStyle(Paint.Style.FILL);

        TextPaint backgroundPaint = new TextPaint();
        backgroundPaint.setColor(Color.LTGRAY);
        backgroundPaint.setStyle(Paint.Style.FILL);

        for (Position position : positionList) {
            paint.setTextSize(position.getWidth());
            final Rect scaledRect = position.getRect();

            canvasFinal.drawRect(scaledRect, backgroundPaint);

            final float x = (float) scaledRect.left;
            float y = (float) scaledRect.top + paint.getTextSize();

            for (final String line : position.getLabel().split("\n")) {
                canvasFinal.drawText(line, x, y, paint);
                y += paint.descent() - paint.ascent();
            }

        }
        bitmap.recycle();

        return mutableBitmap;
    }

    static float getAsFloat(Object o) {
        assert (o != null);
        return Float.parseFloat(o + "");
    }

    static Position getPositionFromLayout(HashMap<String, Object> wLayout) {
        final float pixelDensity = Connect.INSTANCE.getPixelDensity();
        final boolean isMasked = (wLayout.get("masked") + "").compareTo("true") == 0;
        final Object positionObject = wLayout.get("position");
        final Position position = new Position();

        if (positionObject instanceof Map) {
            @SuppressWarnings("unchecked") final Map<String, String> widgetPosition = (Map<String, String>) positionObject;
            final int x = Math.round(getAsFloat(widgetPosition.get("x")) * pixelDensity);
            final int y = Math.round(getAsFloat(widgetPosition.get("y")) * pixelDensity);
            final int width = Math.round(getAsFloat(widgetPosition.get("width")) * pixelDensity);
            final int height = Math.round(getAsFloat(widgetPosition.get("height")) * pixelDensity);
            final Rect rect = new Rect(x, y, x + width, y + height);
            final HashMap<String, Object> currentState = getCurrentState(wLayout);
            final String text = (currentState == null) ? "" : currentState.get("text") + "";

            ConnectFlutterPlugin.LOGGER.log(Level.INFO, "*** Layout -- x: " + x + ", y: " + y + ", text: " + text);

            position.setRect(rect);
            position.setX(x);
            position.setY(y);
            position.setHeight(height);
            // Set width to 0 for masking text to cause the font size to be calculated on rect size!
            position.setWidth(isMasked ? 0 : width);
            // Note: an image can be masked, if which case, currentState will be null and text
            // will default to the empty string. This results in the image rectangle
            // being obscured and NO text mask being overlayed on top.
            position.setLabel(isMasked ? text : null);
        }

        return position;
    }

    static HashMap<String, Object> getCurrentState(HashMap<String, Object> wLayout) {
        final Object currStateObject = wLayout.get("currState");

        if (currStateObject instanceof Map) {
            @SuppressWarnings("unchecked")
            HashMap<String, Object> state = (HashMap<String, Object>) currStateObject;
            return state;
        }
        return null;
    }

    static Position scalePosition(Position position, float scaleW, float scaleH) {
        final Position scaledPosition = new Position();
        final Rect rect = position.getRect();

        rect.left *= scaleW;
        rect.right *= scaleW;
        rect.top *= scaleH;
        rect.bottom *= scaleH;
        scaledPosition.setRect(rect);
        scaledPosition.setX(Math.round(position.getX() * scaleW));
        scaledPosition.setY(Math.round(position.getY() * scaleH));
        scaledPosition.setWidth(Math.round(position.getWidth() * scaleW));
        scaledPosition.setHeight(Math.round(position.getHeight() * scaleH));
        scaledPosition.setLabel(position.getLabel());

        return scaledPosition;
    }

    static void setControls(Layout layout, List<HashMap<String, Object>> widgetLayouts, float scaleW, float scaleH, List<Position> maskPositions) {
        final Map<String, IdType> typeMap = new HashMap<String, IdType>() {
            {
                put("-4", IdType.XPATH);
                put("-1", IdType.ID);
                put("-3", IdType.DYNAMICID);
            }
        };

        if (widgetLayouts == null) {
            ConnectFlutterPlugin.LOGGER.log(Level.INFO, "No widget layouts");
            return;
        }

        for (HashMap<String, Object> wLayout : widgetLayouts) {
            final BaseTarget baseTarget = new BaseTarget();
            final String id = wLayout.get("id") + "";
            final String sType = wLayout.get("idType") + "";
            final IdType idType = typeMap.get(sType);
            final String tlType = wLayout.get("tlType") + "";
            final int zIndex = Integer.parseInt(wLayout.get("zIndex") + "");

            String xpath = wLayout.get("xpath") + "";
            if (xpath.isEmpty() && idType == IdType.XPATH) {
                xpath = id;
            }

            final Position position = getPositionFromLayout(wLayout);
            final Position scaledPosition = scalePosition(position, scaleW, scaleH);
            final PropertyName property = new PropertyName(id, idType, xpath, 501);

            property.setCssId(wLayout.get("cssId") + "");
            baseTarget.setzIndex(zIndex);
            baseTarget.setId(property);
            baseTarget.setId(wLayout.get("originalId") + "");
            baseTarget.setType(wLayout.get("type") + "");
            baseTarget.setSubType(wLayout.get("subType") + "");

            baseTarget.setPosition(scaledPosition);
            baseTarget.setTlType(tlType);

            final Style style = new Style();
            final Object styleObject = wLayout.get("style");
            @SuppressWarnings("unchecked") final HashMap<String, String> accessibility = (HashMap<String, String>) wLayout.get("accessibility");

            String maskedString = null;
            
            if (accessibility != null) {
                final Accessibility accessibilityForMask = new Accessibility(
                        accessibility.get("id"),
                        accessibility.get("label"),
                        accessibility.get("hint"));

                if (!TextUtils.isEmpty(accessibility.get("label"))) {
                    maskedString = compareAccessibilityListAndMask(Connect.INSTANCE.getCurrentLogicalPageName(), accessibilityForMask, accessibility.get("label"));

                    // Masked, add to position list for masking
                    if (!maskedString.equals(accessibilityForMask.getLabel())) {
                        maskPositions.add(position);
                    } else {
                        // Masked Widget, skip currstate
                        baseTarget.setCurrentState(getCurrentState(wLayout));
                    }
                    LogInternal.log("Masked label " + accessibility.get("label") + ", to " + maskedString);
                }
                
                baseTarget.setAccessibility(accessibilityForMask);
            }

            if (styleObject instanceof Map) {
                @SuppressWarnings("unchecked") final HashMap<String, String> styleMap = (HashMap<String, String>) styleObject;

                if (tlType.contentEquals("image")) {
                    ConnectFlutterPlugin.LOGGER.log(Level.INFO, "Ignoring image style in Android");
                } else {
                    final long textColor = Long.parseLong(styleMap.get("textColor") + "");
                    final long textAlphaColor = Long.parseLong(styleMap.get("textAlphaColor") + "");
                    final long textAlphaBGColor = Long.parseLong(styleMap.get("textAlphaBGColor") + "");
                    final String textAlign = styleMap.get("textAlign");
                    final int paddingTop = Integer.parseInt(styleMap.get("paddingTop") + "");
                    final int paddingBottom = Integer.parseInt(styleMap.get("paddingBottom") + "");
                    final int paddingLeft = Integer.parseInt(styleMap.get("paddingLeft") + "");
                    final int paddingRight = Integer.parseInt(styleMap.get("paddingRight") + "");
                    final Boolean hidden = Boolean.valueOf(styleMap.get("hidden"));
                    final long colorPrimary = Long.parseLong(styleMap.get("colorPrimary") + "");
                    final long colorPrimaryDark = Long.parseLong(styleMap.get("colorPrimaryDark") + "");
                    final long colorAccent = Long.parseLong(styleMap.get("colorAccent") + "");

                    style.setTextColor(textColor);
                    style.setTextAlphaColor(textAlphaColor);
                    style.setTextBGAlphaColor(textAlphaBGColor);
                    style.setTextAlignment(textAlign);
                    style.setPaddingTop(paddingTop);
                    style.setPaddingBottom(paddingBottom);
                    style.setPaddingLeft(paddingLeft);
                    style.setPaddingRight(paddingRight);
                    style.setHidden(hidden);
                    style.setColorPrimary(colorPrimary);
                    style.setColorPrimaryDark(colorPrimaryDark);
                    style.setColorAccent(colorAccent);
                }

                baseTarget.setStyle(style);
            }

            final Object imageObject = wLayout.get("image");

            if (imageObject != null) {
                ConnectFlutterPlugin.LOGGER.log(Level.INFO, "*#* image Object found: " + imageObject.getClass());
            }

            if (imageObject instanceof Map) {
                Image image;

                if (EOCore.getConfigItemBoolean("GetImageDataOnScreenLayout", TealeafEOLifecycleObject.getInstance())) {
                    @SuppressWarnings("unchecked") final Map<String, Object> imageMap = (HashMap<String, Object>) imageObject;
                    if (imageMap.size() != imageItems) {
                        ConnectFlutterPlugin.LOGGER.log(Level.INFO, "*#* # of image components incorrect: " + imageMap.size());
                        continue;
                    }
                    final byte[] imageBytes = (byte[]) imageMap.get("base64Image");
                    final int width = Integer.parseInt(imageMap.get("width") + "");
                    final int height = Integer.parseInt(imageMap.get("height") + "");
                    final Bitmap bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888);

                    if (imageBytes == null) {
                        ConnectFlutterPlugin.LOGGER.log(Level.INFO, "*#* image data not found");
                        continue;
                    }
                    bitmap.copyPixelsFromBuffer(ByteBuffer.wrap(imageBytes));

                    final Bitmap.CompressFormat compressFormat = EnhancedImageUtil.getCompressFormat();
                    final ByteArrayOutputStream stream = new ByteArrayOutputStream();
                    final int percent = EnhancedImageUtil.getPercentToCompressImage();

                    bitmap.compress(compressFormat, percent, stream);

                    final byte[] imageFileBytes = stream.toByteArray();

                    StringBuilder start = new StringBuilder();
                    for (int i = 0; i < 3; i++)
                        start.append(Integer.toHexString(((int) imageFileBytes[i]) & 0xff));

                    ConnectFlutterPlugin.LOGGER.log(Level.INFO, "Image file length:" + imageFileBytes.length + ", " +
                            "hex start: " + start);

                    final String md5 = new Md5(imageFileBytes).asString();
                    final String filename = "img-" + percent + "-" + md5 + "." + EnhancedImageUtil.getImageType();

                    ConnectFlutterPlugin.LOGGER.log(Level.INFO, "*#* image name: " + filename + ", size: " +
                            imageFileBytes.length + ", w: " + bitmap.getWidth() + ", h: " + bitmap.getHeight());

                    if (dumpImage) {
                        FileUtil.saveImage(filename, imageFileBytes);
                    }

                    image = new Image(imageFileBytes);
                    image.setType("image");
                    image.setValue(md5);
                    image.setMimeExtension(EnhancedImageUtil.getImageType());
                } else {
                    image = null; //TBD: Provide basic image info (i.e. but not image itself)
                }

                baseTarget.setImage(image);
            }
            
            layout.getControls().add(baseTarget);
        }
    }

    static void logLayout(Activity activity, String currentName, Layout layout, byte[] imageBytes) {
        if (activity != null && activity.getWindow() != null) {
            String className = activity.getLocalClassName();
            final View view = activity.getWindow().getDecorView();

            final String currentLayoutName = currentName;

            try {
                saveScreenImage(currentName, imageBytes);

                if (!TextUtils.isEmpty(Connect.INSTANCE.getCurrentLogicalPageName())) {
                    layout.setName(currentLayoutName);
                } else {
                    layout.setName(className);
                }

                final Style style = new Style();

                if (view != null) {
                    TypedArray array = null;
                    try {
                        array = Connect.INSTANCE.getApplication().getApplicationContext().getTheme().obtainStyledAttributes(new int[]{16842801, 16842806});
                        if (style.getBgColor() == -1L) {
                            style.setBgColor(array.getColor(0, 16711935));
                        }

                        if (style.getTextColor() == -1L) {
                            style.setTextColor(array.getColor(1, 16711935));
                        }
                    } catch (Exception e) {
                        com.tl.uic.util.LogInternal.logException(e, "Error getting style values.");
                    } finally {
                        if (array != null)
                            array.recycle();
                    }
                }

                // Use the Android w,h values (not Flutter dimensions)
                final float height = EOCore.getEnvironmentalDataService().getDeviceHeight();
                final float width = EOCore.getEnvironmentalDataService().getDeviceWidth();

                layout.setClassName(className);
                layout.setStyle(style);
                layout.setOrientation(EOCore.getEnvironmentalDataService().getPageOrientation());
                layout.setDeviceHeight(height);
                layout.setDeviceWidth(width);

                if (imageBytes != null) {
                    final Image image = new Image(imageBytes);
                    image.setType("image");
                    image.setMimeExtension(EnhancedImageUtil.getImageType());
                    layout.setBackgroundImage(image);
                }

                if (EOCore.getConfigItemBoolean("LogViewLayoutOnScreenTransition", TealeafEOLifecycleObject.getInstance())) {
                    final LayoutPlaceHolder layoutPlaceHolder = TLFCache.addLayoutPlaceHolder(Connect.INSTANCE.getCurrentSessionId());
                    if (layout.getCanUpdate()) {
                        TLFCache.updateMessage(layout, layoutPlaceHolder);
                    } else {
                        layout.setLayoutPlaceHolder(layoutPlaceHolder);
                        TLFCache.setLayout(layout);
                    }
                }
            } catch (Exception e) {
                com.tl.uic.util.LogInternal.logException(e, "Error trying to logLayout.");
            }
        }
    }
}

class GestureUtil {
    static boolean isFlutterGestureEvent;

    static GestureControl createGestureControl(Activity activity, float x, float y) {
        final View rootView = activity.getWindow().getDecorView();
        final ArrayList<Object> viewItems = getViewByXY(rootView, x, y);
        final View view = (View) viewItems.get(0);

        if (view != null && !(view instanceof WebView)) {
            final GestureControl gestureControl = new GestureControl();
            GestureControlPosition gestureControlPosition = new GestureControlPosition();
            gestureControlPosition.setHeight(view.getHeight());
            gestureControlPosition.setWidth(view.getWidth());
            final int[] pos = new int[2];
            view.getLocationOnScreen(pos);
            float relX = Math.abs(x - (float) pos[0]) / (float) view.getWidth();
            float relY = Math.abs(y - (float) pos[1]) / (float) view.getHeight();
            gestureControlPosition.setRelX((float) Math.round(relX * 10000.0F) / 10000.0F);
            gestureControlPosition.setRelY((float) Math.round(relY * 10000.0F) / 10000.0F);
            gestureControl.setGestureControlPosition(gestureControlPosition);
            PropertyName propertyName = (PropertyName) viewItems.get(1);
            gestureControl.setId(propertyName);
            gestureControl.setSubType(view.getClass().getSuperclass() != null ? view.getClass().getSuperclass().getSimpleName() : null);
            gestureControl.setType(view.getClass().getSimpleName());
            return gestureControl;
        }
        return null;
    }

    static ArrayList<Object> getViewByXY(View rootView, float x, float y) {
        final ArrayList<Object> arrayList = new ArrayList<>();
        View result = null;
        String xpath = "[null_control]";
        PropertyName propertyName;

        if (rootView != null) {
            final CopyOnWriteArrayList<View> possibleXYViews = new CopyOnWriteArrayList<>();

            final PropertyName initialXPath = getPropertyName(rootView, null, 0, getInitialZIndex());
            printLayoutData(rootView, initialXPath.getId(), 0, initialXPath, getInitialZIndex());
            xpath = initialXPath.getXPath();

            if (rootView instanceof ViewGroup) {
                xpath = getViewByXYHelper(rootView, x, y, initialXPath.getXPath(), possibleXYViews);
                if (possibleXYViews.size() > 0) {
                    result = possibleXYViews.get(possibleXYViews.size() - 1);
                    possibleXYViews.clear();
                }
            }
            propertyName = getPropertyName(result, xpath, 0, getInitialZIndex());
        } else {
            propertyName = new PropertyName(xpath, IdType.XPATH, xpath, getInitialZIndex());
        }

        arrayList.add(result);
        arrayList.add(propertyName);
        return arrayList;
    }


    static String getViewByXYHelper(View rootView, float x, float y, String xpath, CopyOnWriteArrayList<View> possibleXYViews) {
        String finalXPath = xpath;

        if (rootView != null && rootView.getVisibility() != View.INVISIBLE) {
            if (rootView instanceof ViewGroup) {
                ViewGroup viewGroup;
                viewGroup = (ViewGroup) rootView;
                for (int i = 0; i < viewGroup.getChildCount(); ++i) {
                    View child = viewGroup.getChildAt(i);
                    finalXPath = printLayoutData(child, xpath, i, null, getInitialZIndex());
                    testViewXY(child, x, y, possibleXYViews);
                    finalXPath = getViewByXYHelper(child, x, y, finalXPath, possibleXYViews);
                }
            } else {
                testViewXY(rootView, x, y, possibleXYViews);
            }
            return finalXPath;
        }
        return xpath;
    }

    static void testViewXY(View view, float x, float y, CopyOnWriteArrayList<View> possibleXYViews) {
        Position position = getPosition(view);
        float xpdStart = (float) position.getX();
        float ypdStart = (float) position.getY();
        float xpdEnd = xpdStart + (float) position.getWidth();
        float ypdEnd = ypdStart + (float) position.getHeight();
        if (x >= xpdStart && x <= xpdEnd && y >= ypdStart && y <= ypdEnd) {
            possibleXYViews.add(view);
        }
    }

    static Position getPosition(View view) {
        Position position = new Position();
        if (view == null) {
            return position;
        }

        position.setHeight(view.getHeight());
        position.setWidth(view.getWidth());

        int[] location = new int[2];
        if (Build.VERSION.SDK_INT >= 28) {
            view.getLocationInWindow(location);
        } else {
            view.getLocationOnScreen(location);
        }
        position.setX(location[0]);
        position.setY(location[1]);

        return position;
    }

    static String printLayoutData(View view, String xpath, int index, PropertyName propertyName, int zIndex) {
        final PropertyName id = propertyName == null ? getPropertyName(view, xpath, index, zIndex) : propertyName;

        return id.getXPath();
    }

    static int getInitialZIndex() {
        final int zindex = EOCore.getConfigItemInt("InitialZIndex", TealeafEOLifecycleObject.getInstance());
        return zindex <= 0 ? 500 : zindex;
    }

    static PropertyName getPropertyName(View view, String xpath, int index, int zIndex) {
        final PropertyName propertyName = new PropertyName("-1", IdType.DYNAMICID, xpath, zIndex);
        try {
            propertyName.setId(getXPath(view, xpath, index));
            propertyName.setIdType(IdType.XPATH);
            propertyName.setXPath(propertyName.getId());
        } catch (Exception e) {
            com.ibm.eo.util.LogInternal.logException(TealeafEOLifecycleObject.getInstance().name(), e, "Library Error: Trying to get property id for view - " + view.getId());
        }

        if ("-1".equals(propertyName.getId())) {
            propertyName.setId(view.hashCode() + "h");
            propertyName.setIdType(IdType.DYNAMICID);
        }

        if (!IdType.XPATH.equals(propertyName.getIdType())) {
            propertyName.setXPath(getXPath(view, xpath, index));
        }

        return propertyName;
    }

    static String getXPath(View view, String xpath, int index) {
        final StringBuilder sb = new StringBuilder();

        if (xpath != null) {
            sb.append(xpath);
        }

        return sb.append("[").append(getClassNameUpperCase(view)).append(",").append(index).append("]").toString();
    }

    static String getClassNameUpperCase(Object object) {
        final String className = getClassName(object);
        return className.isEmpty() ? className : className.replaceAll("[^A-Z]", "");
    }

    static String getClassName(Object object) {
        return object == null ? "" : object.getClass().getName().substring(object.getClass().getName().lastIndexOf(46) + 1);
    }
}

// --- TBD: End of code to be moved out (and/or re-factored).

/**
 * ConnectFlutterPlugin
 */
public class ConnectFlutterPlugin implements FlutterPlugin, ActivityAware, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    final static Logger LOGGER = Logger.getLogger(Logger.GLOBAL_LOGGER_NAME);
    final static String TAG = ConnectFlutterPlugin.class.getSimpleName();
    final static String NO_METHODCALL = "500: No MethodCall request";
    final static String NO_ARGS = "501: arguments is null";
    final static String INVOKE_EXCEPTION = "502: Exception in request: ";

    final static boolean FLUTTER_GESTURE_EVENT = true;

    private Object lastPointerEvent = null;
    private Object lastPointerUpEvent = null;
    private long lastDown = -1L;
    private String lastPage = "";
    private Image lastPageImage = null;

    // TBD: Do we need to compare screens on gesture events?
    // private Bitmap lastRawScreen = null;

    // For some Android devices, the flutter screen size is different. Hence we need
    // to scale coordinates and sizes accordingly (and incorporate the pixel density).
    // Values passed to Connect playback need scaling whereas for values used locally, the flutter
    // coordinates only need to be adjusted with the density.

    private float scaleWidth = 1.0f;
    private float scaleHeight = 1.0f;

    private MethodChannel channel;
    private Object renderer;
    private ActivityPluginBinding activityBinding;
    private ExecutorService _executorPool;

    @SuppressWarnings("deprecation")
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding flutterPluginBinding) {
        channel = new MethodChannel(flutterPluginBinding.getBinaryMessenger(), "connect_flutter_plugin");
        channel.setMethodCallHandler(this);

        channel.invokeMethod("hello?", null, new Result() {
            @Override
            public void success(Object o) {
                LOGGER.log(Level.INFO, "Plugin hello message: " + o.toString());
            }

            @Override
            public void error(@NonNull String s, String s1, Object o) {
                LOGGER.log(Level.INFO, "Plugin hello message ERROR: " + s + ", " + s1);
            }

            @Override
            public void notImplemented() {
                LOGGER.log(Level.INFO, "Plugin hello message test (NOT IMPLEMENTED VERIFIED)");
            }
        });

        // This is a 'blocked' issue according to flutter developers
        renderer = flutterPluginBinding.getFlutterEngine().getRenderer();
        FlutterRenderer flutterRenderer = (FlutterRenderer) renderer;

        // Put a cache engine for SDK code
        FlutterEngineCache.getInstance().put("connect_cache_engine", flutterPluginBinding.getFlutterEngine());

        flutterRenderer.addIsDisplayingFlutterUiListener(new FlutterUiDisplayListener() {
            @Override
            public void onFlutterUiDisplayed() {
                // Set Flutter Engine, when UI is visible
                //Connect.INSTANCE.setFlutterEngine(new WeakReference<FlutterEngine>(flutterPluginBinding.getFlutterEngine()));
            }

            //
            @Override
            public void onFlutterUiNoLongerDisplayed() {
                // Do nothing
            }
        });

        // Enable Connect library
        Connect.INSTANCE.init(((Application) flutterPluginBinding.getApplicationContext()));
        Connect.INSTANCE.enable();
    }

    // ActivityAware  overrides
    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;

        // TODO:  Init Activity state, but is it necessary?
        Connect.INSTANCE.onResume(getActivity(), null);
    }

    @Override
    public void onDetachedFromActivity() {
        activityBinding = null;

        if (getActivity() != null) {
            Connect.INSTANCE.onPause(getActivity(), null);
        }
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        activityBinding = binding;
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        activityBinding = null;
    }

    public Activity getActivity() {
        // return (activityBinding != null) ? activityBinding.getActivity() : null;
        Activity activity = activityBinding == null ? null : activityBinding.getActivity();

        return activity;
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        if (call.method == null) {
            result.error(NO_METHODCALL, "method name is null", getStackTraceAsString());
            return;
        }

        final Object args = call.arguments;
        final String argString = (args == null) ? "null!" : args.toString();
        final String request = call.method.toLowerCase();

        LOGGER.log(Level.INFO, "onMethodCall: " + request + ", args: " + argString);
        FileUtil.setPermissionToWrite(getActivity());

        try {
            switch (call.method.toLowerCase()) {
                case "getplatformversion": {
                    result.success("Android " + android.os.Build.VERSION.RELEASE);
                    break;
                }
                case "getConnectversion": {
                    result.success(Connect.VERSION);
                    break;
                }
                case "getConnectsessionid": {
                    final String sessionId = Connect.INSTANCE.getCurrentSessionId();
                    result.success(sessionId);
                    break;
                }
                case "getpluginversion": {
                    result.error("deprecated error", "getpluginversion no longer supported in native", getStackTraceAsString());
                    break;
                }
                case "getappkey": {
                    result.success(EOCore.getConfigItemString(Connect.TLF_APP_KEY, TealeafEOLifecycleObject.getInstance()));
                    break;
                }
                case "getglobalconfiguration": {
                    result.success(tlGetConfig());
                    break;
                }
                case "setenv": {
                    if (args == null) {
                        result.error(NO_ARGS, "set screen environment requires arguments list", getStackTraceAsString());
                        return;
                    }
                    // tlSetEnvironment(args);
                    result.success(null);
                    break;
                }
                case "ontap": {
                    result.error("deprecated error", "ontap no longer supported", getStackTraceAsString());
                    break;
                }
                case "pointerevent": {
                    if (args == null) {
                        result.error(NO_ARGS, "pointer event requires arguments list", getStackTraceAsString());
                        return;
                    }
                    tlPointerEventMessage(args);
                    result.success(null);
                    break;
                }
                case "gesture": {
                    if (args == null) {
                        result.error(NO_ARGS, "gesture event requires arguments list", getStackTraceAsString());
                        return;
                    }
                    tlGestureMessage(args);
                    result.success(null);
                    break;
                }
                case "logscreenviewcontextunload": {
                    if (args == null) {
                        result.error(NO_ARGS, "logscreenviewcontextunload event requires arguments list", getStackTraceAsString());
                        return;
                    }
                    logScreenViewContextUnLoad(args);
                    result.success(true);
                    break;
                }
                case "screenview": {
                    if (args == null) {
                        result.error(NO_ARGS, "screenview event requires arguments list", getStackTraceAsString());
                        return;
                    }
                    tlScreenviewMessage(args);
                    result.success(true);
                    break;
                }
                case "logscreenlayout": {
                    if (args == null) {
                        result.error(NO_ARGS, "screenview event requires arguments list", getStackTraceAsString());
                        return;
                    }
                    logScreenLayout(args);
                    result.success(true);
                    break;
                }
                case "exception": {
                    if (args == null) {
                        result.error(NO_ARGS, "exception event requires arguments list", getStackTraceAsString());
                        return;
                    }
                    tlExceptionMessage(args);
                    result.success(null);
                    break;
                }
                case "customevent": {
                    if (args == null) {
                        result.error(NO_ARGS, "custom event requires arguments list", getStackTraceAsString());
                        return;
                    }
                    tlCustomEventMessage(args);
                    result.success(null);
                    break;
                }
                case "connection": {
                    if (args == null) {
                        result.error(NO_ARGS, "connection event requires arguments list", getStackTraceAsString());
                        return;
                    }
                    tlConnectionMessage(args);
                    result.success(null);
                    break;
                }
                case "masktext": { //TBD: Make deprecated or just remove
                    if (args == null) {
                        result.error(NO_ARGS, "mask text requires arguments list", getStackTraceAsString());
                        return;
                    }
                    result.success(tlMaskText(args));
                    break;
                }
                case "focuschanged":
                    if (args == null) {
                        result.error(NO_ARGS, "focus changed event requires arguments list", getStackTraceAsString());
                        return;
                    }
                    tlFocusChangeMessage(args);
                    result.success(null);
                    break;
                case "logperformanceevent":
                    if (args == null) {
                        result.error(NO_ARGS, "log performance event requires arguments list", getStackTraceAsString());
                        return;
                    }
                    result.success(tlLogPerformanceMessage(args));
                    break;
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Throwable t) {
            final String stackTraceString = getStackTraceAsString(t.getStackTrace());

            LOGGER.log(Level.INFO, "onMethodCall exception: " + request + ", msg: " +
                    t.getMessage() + ", stktrace: " + stackTraceString);

            result.error(INVOKE_EXCEPTION + request, t.getMessage(), stackTraceString);
        }
    }

    private boolean tlLogPerformanceMessage(Object args) {
        LOGGER.log(Level.INFO, "Connect log performance message");
        
        final int logLevel = EOMonitoringLevel.kEOMonitoringLevelInfo.getValue();
        TLFPerformanceNavigationType navigationType;
        final int naviagtionInt = Integer.parseInt(checkForParameter(args, "navigationType"));
        switch (naviagtionInt) {
            case 0:
                navigationType = TLFPerformanceNavigationType.NAVIGATE;
                break;
            case 1:
                navigationType = TLFPerformanceNavigationType.RELOAD;
                break;
            case 2:
                navigationType = TLFPerformanceNavigationType.BACK_FORWARD;
                break;
            case 255:
                navigationType = TLFPerformanceNavigationType.RESERVED;
                break;
            default:
                navigationType = TLFPerformanceNavigationType.NAVIGATE;
                break;
        }
        final long redirectCount = Long.parseLong(checkForParameter(args, "redirectCount"));
        final long navigationStart = Long.parseLong(checkForParameter(args, "navigationStart"));
        final long unloadEventStart = Long.parseLong(checkForParameter(args, "unloadEventStart"));
        final long unloadEventEnd = Long.parseLong(checkForParameter(args, "unloadEventEnd"));
        final long redirectStart = Long.parseLong(checkForParameter(args, "redirectStart"));
        final long redirectEnd = Long.parseLong(checkForParameter(args, "redirectEnd"));
        final long loadEventStart = Long.parseLong(checkForParameter(args, "loadEventStart"));
        final long loadEventEnd = Long.parseLong(checkForParameter(args, "loadEventEnd"));

        return Connect.INSTANCE.logPerformanceEvent(logLevel, navigationType, redirectCount,
                navigationStart, unloadEventStart, unloadEventEnd, redirectStart, redirectEnd,
                loadEventStart, loadEventEnd);
    }

    void tlConnectionMessage(Object args) throws Exception {
        LOGGER.log(Level.INFO, "Connect message communication activity");

        final String url = checkForParameter(args, "url");
        final int statusCode = Integer.parseInt(checkForParameter(args, "statusCode"));
        final long responseSize = Long.parseLong(checkForParameter(args, "responseDataSize"));
        final long initTime = Long.parseLong(checkForParameter(args, "initTime"));
        final long loadTime = Long.parseLong(checkForParameter(args, "loadTime"));

        final Connection connection = new Connection();
        connection.setUrl(url);
        connection.setInitTime(initTime);
        connection.setLoadTime(loadTime);
        connection.setResponseDataSize(responseSize);
        connection.setStatusCode(statusCode);

        Connect.INSTANCE.logConnection(connection);
    }

    /**
     * @param args double x, x coordinate of the view on which the focus changed
     *             double y, y coordinate of the view on which the focus changed
     *             boolean focused, true if the the view was focused, false otherwise
     * @throws Exception
     */
    void tlFocusChangeMessage(Object args) throws Exception {
        LOGGER.log(Level.INFO, "Connect on focus changed logging");

        // Parse arguments
        final float x = Float.parseFloat(checkForParameter(args, "x"));
        final float y = Float.parseFloat(checkForParameter(args, "y"));
        final boolean focused = Boolean.parseBoolean(checkForParameter(args, "focused"));
        
        // Get the view
        final Activity activity = getActivity();
        final View rootView = activity.getWindow().getDecorView();
        final ArrayList<Object> viewItems = GestureUtil.getViewByXY(rootView, x, y);
        final View view = (View) viewItems.get(0);
        LOGGER.log(Level.INFO, String.format("Connect on focus changed view found: %s\n %s", view.getClass().getSimpleName(), view.toString()));

        // Get event type
        final String eventType = focused ? Connect.TLF_ON_FOCUS_CHANGE_IN : Connect.TLF_ON_FOCUS_CHANGE_OUT;

        // Log event
        Connect.INSTANCE.logEvent(view, eventType);
    }

    void tlCustomEventMessage(Object args) throws Exception {
        LOGGER.log(Level.INFO, "Connect message custom event");

        final String eventName = checkForParameter(args, "eventname");
        final HashMap<String, String> customData = parameter(args, "data");
        final Integer logLevel = parameter(args, "loglevel");

        Connect.INSTANCE.logCustomEvent(eventName, customData, logLevel == null ? EOCore.getDefaultLogLevel() : logLevel);
    }

    // void tlSetEnvironment(Object args) throws Exception {
    //     final int flutterWidth = checkForParameter(args, "screenw");
    //     final int flutterHeight = checkForParameter(args, "screenh");
    //     final float pixelDensity = Connect.INSTANCE.getPixelDensity();
    //     final float deviceHeight = EOCore.getEnvironmentalDataService().getDeviceHeight() * pixelDensity;
    //     final float deviceWidth = EOCore.getEnvironmentalDataService().getDeviceWidth() * pixelDensity;

    //     if (flutterHeight != 0 && flutterWidth != 0) {
    //         scaleWidth = deviceWidth / flutterWidth;
    //         scaleHeight = deviceHeight / flutterHeight;

    //         ConnectFlutterPlugin.LOGGER.log(Level.INFO, "Environment (density adjusted). screen width: " +
    //                 deviceWidth + ", screen height: " + deviceHeight + ", flutter w,h: " + flutterWidth + "," +
    //                 flutterHeight + ", scaleW: " + scaleWidth + ", scaleH: " + scaleHeight + ", density: " +
    //                 pixelDensity);
    //     } else {
    //         ConnectFlutterPlugin.LOGGER.log(Level.INFO, "Flutter screen dimension(s) can not be 0!");
    //     }
    // }

    /**
     * @param args Flutter app Gesture event, and its screen meta data.
     * @return CountDownlatch Used for testing.
     */
    CountDownLatch tlGestureMessage(Object args) {
        final CountDownLatch cdl = new CountDownLatch(1);

        // Do not add gesture control to queue
        if (getActivity() == null) {
            cdl.countDown();
            return cdl;
        }
        if (_executorPool == null || _executorPool.isShutdown()) {
            _executorPool = Executors.newCachedThreadPool();
        }

        final String lastPage = this.lastPage;
        GestureUtil.isFlutterGestureEvent = true;

        _executorPool.execute(() -> {
            try {
                final String tlType = checkForParameter(args, "tlType");
                final List<HashMap<String, Object>> widgetLayouts = checkForParameter(args, "layoutParameters");
                final Layout layout = new Layout();
                final Bitmap screenBitmap = screenSnapshot(getActivity(), renderer);

                LOGGER.log(Level.INFO, "Connect message gesture event: " + "tlType: " + tlType + ", page: " +
                        lastPage + ", last pointer event was up event: " + (lastPointerEvent == lastPointerUpEvent));

                /* Keep in case we need to take snapshot */
                final List<Position> maskedPositions = new ArrayList<>();

                for (HashMap<String, Object> wLayout : widgetLayouts) {
                    final Position position = ScreenUtil.getPositionFromLayout(wLayout);

                    if (position.getLabel() != null) {
                        maskedPositions.add(position);
                    }
                }

                if (EOCore.getConfigItemBoolean("SetGestureDetector", TealeafEOLifecycleObject.getInstance())) {
                    final Activity activity = getActivity();

                    if (FLUTTER_GESTURE_EVENT) {
                        //final byte[] imageBytes = ScreenUtil.takeSnapshotAndCompress(activity, getRenderer(), maskedPositions);
                        ScreenUtil.setControls(layout, widgetLayouts, scaleWidth, scaleHeight, maskedPositions);

                        ScreenUtil.obscureAndCompress(screenBitmap, maskedPositions);

                        if (!Connect.INSTANCE.getGesturePlaceHolder().isEmpty()) {
                            Connect.INSTANCE.getGesturePlaceHolder().take(); // Remove placeholder (not needed?)
                        }
                        logGestureEvent(activity, tlType, args, EOCore.getDefaultLogLevel());
                        lastPointerEvent = null;
                    } else {
                        Connect.INSTANCE.logGestureEvent(activity, motionEvent(), tlType, lastPage);
                    }
                }
            } catch (final Exception e) {
                com.tl.uic.util.LogInternal.logException(e, "Connect plugin error:  Trying to log Gesture.");
            } finally {
                GestureUtil.isFlutterGestureEvent = false;
            }
        });
        return cdl;
    }

    void tlPointerEventMessage(Object args) throws Exception {
        LOGGER.log(Level.INFO, "Connect pointer event at: " + checkForParameter(args, "position", "dx") +
                ',' + checkForParameter(args, "position", "dy"));

//        // We don't need below anymore since the plugin provides Gesture hook, and handling of gesture events
//        if (EOCore.getConfigItemBoolean("SetGestureDetector", TealeafEOLifecycleObject.getInstance())) {
//            final MotionEvent motionEvent = motionEvent(args);
//            assert motionEvent != null;
//            final int action = motionEvent.getAction();
//
//            if (action == MotionEvent.ACTION_UP) {
//                lastPointerUpEvent = args;
//                if (Connect.INSTANCE.getGesturePlaceHolder().isEmpty()) {
//                    final GesturePlaceHolder gph = new GesturePlaceHolder(Connect.INSTANCE.getCurrentSessionId(), "");
//                    Connect.INSTANCE.getGesturePlaceHolder().add(gph);
//                    TLFCache.addMessage(gph); // Placeholder needed fr Android native version of gesture control
//                }
//            }
//        }
        lastPointerEvent = args;
    }

    /**
     * This method logs the layout of the current screen.
     *
     * @param args a map object containing arguments passed to this function.
     *             It is expected to contain "tlType" and "name" keys        final int delay = checkForParameter(args, "delay");.
     * @throws Exception if required parameters are not found in args.
     */
    void logScreenLayout(Object args) throws Exception {
        // Checking for 'tlType' parameter in the args
        final String tlType = checkForParameter(args, "tlType");
        // Checking for 'name' parameter in the args, which is supposed to be the logical name of the current page
        String logicalPageName = checkForParameter(args, "name");
        int delay = 0;

        if (((Map) args).size() == 3 && ((Map<?, ?>) args).get("delay") != null) {
            delay = checkForParameter(args, "delay");
        }

        if (TextUtils.isEmpty(logicalPageName) || "null".equals(logicalPageName)) {
            logicalPageName = Connect.INSTANCE.getCurrentLogicalPageName();
        } else {
            Connect.INSTANCE.setCurrentLogicalPageName(logicalPageName);
        }
        Connect.INSTANCE.resumeConnect(getActivity(), logicalPageName);
    }

    /**
     * This method logs the unload event of the current screen view.
     *
     * @param logicalPageName the logical name of the current page.
     * @param referrer        the source that led the user to this page.
     */
    void logScreenViewContextUnLoad(Object args) throws Exception {
        // Checking for 'name' parameter in the args, which is supposed to be the logical name of the current page
        String logicalPageName = checkForParameter(args, "name");
        // Checking for 'referrer' parameter in the args, which is supposed to be the source that led the user to this page
        final String referrer = checkForParameter(args, "referrer");

        if (TextUtils.isEmpty(logicalPageName) || "null".equals(logicalPageName)) {
            logicalPageName = Connect.INSTANCE.getCurrentLogicalPageName();
        }

        // Logging the view of the current screen with ScreenviewType as UNLOAD and the referrer
        Connect.INSTANCE.logScreenview(getActivity(), logicalPageName, ScreenviewType.UNLOAD, referrer);
    }


    /**
     * Handles Connect type 10 message via Flutter's MethodChannel.
     *
     * @param args Basic types supported by Flutter.
     * @return Count down latch for testing.
     */
    CountDownLatch tlScreenviewMessage(Object args) {
        final CountDownLatch cdl = new CountDownLatch(1);

        // Do not add gesture control to queue
        if (getActivity() == null) {
            cdl.countDown();
            return cdl;
        }
        if (_executorPool == null || _executorPool.isShutdown()) {
            _executorPool = Executors.newCachedThreadPool();
        }

        _executorPool.execute(() -> {
            try {
                final Activity activity = getActivity();
                final Layout layout = new Layout();
                final String tlType = checkForParameter(args, "tlType");
                final String logicalPageName = checkForParameter(args, "logicalPageName");
                final List<HashMap<String, Object>> widgetLayouts = parameter(args, "layoutParameters");
                final List<Position> maskedPositions = new ArrayList<>();

                /**
                 * Create type 2 and set the context for current screen.
                 */
                Connect.INSTANCE.logScreenview(activity, logicalPageName, ScreenviewType.LOAD, lastPage);

                final Bitmap screenBitmap = screenSnapshot(activity, renderer);

                byte[] nextImageBytes = new byte[0];

                if (screenBitmap == null) {
                    LOGGER.log(Level.WARNING, "Warning: Failed to obtain screen snapshot from Flutter!");
                } else {
                    // lastRawScreen = screenBitmap.copy(Bitmap.Config.ARGB_8888, false);
                    ScreenUtil.setControls(layout, widgetLayouts, scaleWidth, scaleHeight, maskedPositions);

                    final byte[] imageBytes = ScreenUtil.obscureAndCompress(screenBitmap, maskedPositions);

                    if (imageBytes == null) {
                        LOGGER.log(Level.WARNING, "Warning: Unable to obscure and/or compress screen image!");
                    } else {
                        nextImageBytes = imageBytes;
                    }
                }

                LOGGER.log(Level.INFO, "Current page (Md5): " + logicalPageName +
                        ", next MD5: " + logicalPageName + ", final image size: " + nextImageBytes.length);

                if (lastPage.contentEquals(logicalPageName)) {
                    LOGGER.log(Level.INFO, "*** Skipping log of screenview, transition screen has not updated");
                    return;
                }
                LOGGER.log(Level.INFO, "*** Screen is updated, logging changed screen.");

                ScreenUtil.logLayout(activity, logicalPageName, layout, nextImageBytes);

                lastPage = logicalPageName;
                lastPageImage = layout.getBackgroundImage();
            } catch (final Exception e) {
                com.tl.uic.util.LogInternal.logException(e, "Connect plugin error:  Trying to log screenview.");
            }
        });
        return cdl;
    }

    void tlExceptionMessage(Object args) throws Exception {
        if (!EOCore.canPostMessage(EOMonitoringLevel.kEOMonitoringLevelCritical.getValue()))
            return;

        LOGGER.log(Level.INFO, "Connect log Exception message in " + TAG);

        final boolean handled = checkForParameter(args, "handled") == null ? true : false;
        final String widgetName = checkForParameter(args, "name");
        final String message = checkForParameter(args, "message");
        final String stacktrace = checkForParameter(args, "stacktrace");

        final String nativeCode = parameter(args, "nativecode");// Can be null
        final HashMap<String, String> appData = parameter(args, "appdata");  // Can be null

        // Check if error occurred in Flutter or native code

        // Flutter exception?
        if (nativeCode == null) {
            Connect.INSTANCE.logExceptionEvent(widgetName, message, stacktrace, !handled);
            return;
        }
        // Application caught exception?
        if (appData != null) {
            final String[] reserved = {"widgetclass", "stacktrace"};

            for (String key : reserved) {
                if (appData.containsKey(key)) {
                    LOGGER.log(Level.INFO, "Custom exception data should not use reserved name: " + key);
                    //TBD: Check that we handle recursive exception calls before enabling.
                    //throw new Exception("Custom exception data should not use reserved name: " + key);
                }
            }
            appData.put("widgetclass", widgetName);
            appData.put("stacktrace", stacktrace);
            Connect.INSTANCE.logException(new Throwable(message), appData, !handled);
            return;
        }
        // Flutter caught native code exception
        final HashMap<String, String> data = new HashMap<>();
        final String nativeMessage = checkForParameter(args, "nativemessage");
        final String nativeStacktrace = checkForParameter(args, "nativestacktrace");

        data.put("widgetclass", widgetName);
        data.put("stacktrace", stacktrace);
        data.put("nativemessage", nativeMessage);
        data.put("nativecode", nativeCode);
        data.put("nativestacktrace", nativeStacktrace);

        Connect.INSTANCE.logException(new Throwable(message), data, !handled);
    }

    private String getStackTraceAsString() {
        return getStackTraceAsString(Thread.currentThread().getStackTrace());
    }

    private String getStackTraceAsString(StackTraceElement[] stackTrace) {
        final StringBuilder sb = new StringBuilder();

        for (StackTraceElement ste : stackTrace)
            sb.append(ste.toString()).append("\n");

        return sb.toString();
    }

    /**
     * Flutter Parameters passed via MethodChannel
     *
     * @param args
     * @param key
     * @param <T>
     * @return
     */
    protected static <T> T checkForParameter(Object args, String key) {
        T value = null;

        try {
            LOGGER.log(Level.INFO, "Checking for parameter: " + key);

            value = parameter(args, key);

            if (value == null) {
                LOGGER.log(Level.INFO, "Parameter: " + key + " not found in: " + (args == null ? "<args is null>" : args.toString()));
            }
        } catch (Exception e) {
            LogInternal.logException("ConnectFlutterPlugin: checkForParameter", e);
        }
        return value;
    }

    protected static <T> T checkForParameter(Object map, String key, String subKey) throws Exception {
        Map<?, ?> subMap = checkForParameter(map, key);
        return checkForParameter(subMap, subKey);
    }

    protected static <T> T parameter(Object map, String key) {
        if (map == null) {
            return null;
        }
        if (map instanceof Map) {
            @SuppressWarnings("unchecked") T parameterMap = (T) ((Map<?, ?>) map).get(key);
            return parameterMap;
        }
        if (map instanceof JSONObject) {
            @SuppressWarnings("unchecked") T jsonMap = (T) ((JSONObject) map).opt(key);
            return jsonMap;
        }
        throw new ClassCastException();
    }

    float withDensity(float scale) {
        return Connect.INSTANCE.getPixelDensity() * scale;
    }

    private MotionEvent motionEvent() throws Exception {
        return lastPointerEvent != null ? motionEvent(lastPointerEvent) : null;
    }

    private MotionEvent motionEvent(Object map) throws Exception {
        try {
            final String event = checkForParameter(map, "action");
            final int action = (event.equals("DOWN") ? MotionEvent.ACTION_DOWN :
                    (event.equals("UP") ? MotionEvent.ACTION_UP :
                            (event.equals("MOVE") ? MotionEvent.ACTION_MOVE : -1)));
            final Double dx = checkForParameter(map, "position", "dx");
            final Double dy = checkForParameter(map, "position", "dy");
            final Double dp = checkForParameter(map, "pressure");
            final float pressure = dp.floatValue();
            final int device = checkForParameter(map, "kind");
            final long timestamp = Long.parseLong(checkForParameter(map, "timestamp"));

            final float x = dx.floatValue() * withDensity(scaleWidth);
            final float y = dy.floatValue() * withDensity(scaleHeight);

            LOGGER.log(Level.INFO, "Motion Event - x,y: " + x + "," + y + ", density (scaled), x: " +
                    scaleWidth + ", y: " + scaleHeight);

            final MotionEvent me = MotionEvent.obtain(timestamp - lastDown, timestamp, action, x, y, pressure,
                    0.1f, 0, 0.1f, 0.1f, device, 0);

            if (action == MotionEvent.ACTION_DOWN) {
                lastDown = timestamp;
            }

            return me;
        } catch (final Exception e) {
            com.tl.uic.util.LogInternal.logException(e, "Connect plugin error:  Trying to get MotionEvent.");
        }
        return null;
    }

    private MotionEvent motionEvent(double dx, double dy, long timestamp) {
        final int action = MotionEvent.ACTION_DOWN;
        final float x = (float) dx * withDensity(scaleWidth);
        final float y = (float) dy * withDensity(scaleHeight);

        LOGGER.log(Level.INFO, "Motion Event - x,y: " + x + "," + y + ", density (scaled), x: " +
                scaleWidth + ", y: " + scaleHeight);

        return MotionEvent.obtain(0, timestamp, action, x, y, 0.0f, 0.1f, 0,
                0.1f, 0.1f, 0, 0);
    }

    private String tlGetLayoutConfig() {
        final JSONObject json = LayoutUtil.getLayoutInfo("");
        return json.toString();
    }

    private String tlGetConfig() {
        final String imageData = EOCore.getConfigItemBoolean("GetImageDataOnScreenLayout",
                TealeafEOLifecycleObject.getInstance()) ? "true" : "false";
        final String jsonString =
                "{" +
                        "\"GlobalScreenSettings\":" + tlGetLayoutConfig() +
                        "," +
                        "\"TealeafBasicConfig\": {" +
                        "\"GetImageDataOnScreenLayout\": " + imageData +
                        "}" +
                        "}";

        LOGGER.log(Level.INFO, "Global Configuration JSON (Android): " + jsonString);

        return jsonString;
    }

    private String tlMaskText(Object args) throws Exception {
        final String text = checkForParameter(args, "text");
        final String page = checkForParameter(args, "page");

        return ValueUtil.maskValue(page, text);
    }

    public static String processString(String inputString) {
        // Define a regular expression pattern to capture content within parentheses or the first word.
        String pattern = "\\(([^)]+)\\)|(\\w+)";
        Pattern regex = Pattern.compile(pattern);
        Matcher matcher = regex.matcher(inputString);

        if (matcher.find()) {
            if (matcher.group(1) != null) {
                // Content within parentheses found, use it.
                return matcher.group(1);
            } else if (matcher.group(2) != null) {
                // No parentheses found, use the first word.
                return matcher.group(2);
            }
        }

        // If no match is found, return null or an appropriate default value.
        return null;
    }

    void logGestureEvent(Activity activity, String eventType, Object args, int logLevel) throws Exception {
        if (!EOCore.canPostMessage(logLevel)) {
            return;
        }

        final String id = checkForParameter(args, "id");
        String targetWidget = checkForParameter(args, "target");
        final HashMap<String, Object> data = parameter(args, "data");
        final Gesture gesture = new Gesture();
        final boolean isSwipe = eventType.contentEquals("swipe");
        final boolean isPinch = eventType.contentEquals("pinch");

        MotionEvent motionEvent1;
        MotionEvent motionEvent2 = null;
        //GesturePlaceHolder gph = null;

        if (isPinch || isSwipe) {
            final double dx = checkForParameter(data, "pointer1", "dx");
            final double dy = checkForParameter(data, "pointer1", "dy");
            final long ts = isPinch ? 0L : Long.parseLong(ConnectFlutterPlugin.checkForParameter(data, "pointer1", "ts"));
            final double dx2 = checkForParameter(data, "pointer2", "dx");
            final double dy2 = checkForParameter(data, "pointer2", "dy");
            final long ts2 = isPinch ? 0L : Long.parseLong(ConnectFlutterPlugin.checkForParameter(data, "pointer2", "ts"));

            motionEvent1 = motionEvent(dx, dy, ts);
            motionEvent2 = motionEvent(dx2, dy2, ts2);
            if (motionEvent1 == null || motionEvent2 == null) {
                return;
            }
        } else {
            if ((motionEvent1 = motionEvent()) == null) {
                return;
            }
        }

        try {
      /* TBD: Investigate whether we really need to link with the placeholder,
              and if so, how to get this to work. The mechanism used to link
              the placeholder (gph) and the actual gesture requires access to
              the cache temp buffer (in TLFCache.java) which is protected or private.
      */
            //if (Connect.getGesturePlaceHolder().size() > 0) {
            // gph = Connect.getGesturePlaceHolder().take();
            // Just remove from queue for now.
            //}
            gesture.setLogLevel(logLevel);

            final EventInfo eventInfo = new EventInfo();
            eventInfo.setTlEvent(eventType);
            targetWidget = (processString(targetWidget));
            eventInfo.setType(targetWidget);
            eventInfo.setSubType("TODO: FIX IT");

            if (motionEvent1.getActionMasked() == 0) {
                eventInfo.setType("ACTION_DOWN");
            } else if (motionEvent1.getActionMasked() == 1) {
                eventInfo.setType("ACTION_UP");
            } else if (motionEvent1.getActionMasked() == 2) {
                eventInfo.setType("ACTION_MOVE");
            }

            Touch[][] touches = null;

            if (isSwipe) {
                final GestureControl gestureControl1Start = GestureUtil.createGestureControl(activity, motionEvent1.getRawX(), motionEvent1.getRawY());
                final GestureControl gestureControl1End = GestureUtil.createGestureControl(activity, motionEvent2.getRawX(), motionEvent2.getRawY());

                if (gestureControl1Start != null && gestureControl1End != null) {
                    touches = new Touch[1][2];
                    touches[0][0] = new Touch(new TouchPosition(motionEvent1), gestureControl1Start);
                    touches[0][1] = new Touch(new TouchPosition(motionEvent2), gestureControl1End);
                    gesture.setTouches(touches);

                    final double vdX = ConnectFlutterPlugin.checkForParameter(data, "velocity", "dx");
                    final double vdY = ConnectFlutterPlugin.checkForParameter(data, "velocity", "dy");
                    final String direction = ConnectFlutterPlugin.checkForParameter(data, "direction");

                    gesture.setVelocityX((float) vdX);
                    gesture.setVelocityY((float) vdY);
                    gesture.setDirection(direction);
                    gestureControl1Start.setId(new PropertyName(id, IdType.XPATH, id, GestureUtil.getInitialZIndex()));
                    gestureControl1End.setId(new PropertyName(id, IdType.XPATH, id, GestureUtil.getInitialZIndex()));
                    gestureControl1Start.setTlType(targetWidget);
                    gestureControl1End.setTlType(targetWidget);
                }
            } else if (isPinch) {
                final GestureControl gestureControl1Start = GestureUtil.createGestureControl(activity, motionEvent1.getRawX(), motionEvent1.getRawY());
                final GestureControl gestureControl1End = GestureUtil.createGestureControl(activity, motionEvent2.getRawX(), motionEvent2.getRawY());
                final GestureControl gestureControl2Start = GestureUtil.createGestureControl(activity, motionEvent1.getRawX(), motionEvent1.getRawY());
                final GestureControl gestureControl2End = GestureUtil.createGestureControl(activity, motionEvent2.getRawX(), motionEvent2.getRawY());

                if (gestureControl1Start != null && gestureControl1End != null && gestureControl2Start != null && gestureControl2End != null) {
                    final double vdX = ConnectFlutterPlugin.checkForParameter(data, "velocity", "dx");
                    final double vdY = ConnectFlutterPlugin.checkForParameter(data, "velocity", "dy");
                    final String direction = ConnectFlutterPlugin.checkForParameter(data, "direction");

                    gesture.setVelocityX((float) vdX);
                    gesture.setVelocityY((float) vdY);
                    gesture.setDirection(direction);

                    touches = new Touch[2][2];

                    touches[0][0] = new Touch(new TouchPosition(motionEvent1), gestureControl1Start);
                    touches[0][1] = new Touch(new TouchPosition(motionEvent2), gestureControl1End);
                    touches[1][0] = new Touch(new TouchPosition(motionEvent1), gestureControl2Start);
                    touches[1][1] = new Touch(new TouchPosition(motionEvent2), gestureControl2End);
                    gestureControl1Start.setId(new PropertyName(id, IdType.XPATH, id, GestureUtil.getInitialZIndex()));
                    gestureControl1End.setId(new PropertyName(id, IdType.XPATH, id, GestureUtil.getInitialZIndex()));
                    gestureControl1Start.setTlType(targetWidget);
                    gestureControl1End.setTlType(targetWidget);
                    gestureControl2Start.setId(new PropertyName(id, IdType.XPATH, id, GestureUtil.getInitialZIndex()));
                    gestureControl2End.setId(new PropertyName(id, IdType.XPATH, id, GestureUtil.getInitialZIndex()));
                    gestureControl2Start.setTlType(targetWidget);
                    gestureControl2End.setTlType(targetWidget);
                    eventInfo.setType("onScale");
                }
            } else {
                final GestureControl gestureControl = GestureUtil.createGestureControl(activity, motionEvent1.getRawX(), motionEvent1.getRawY());

                if (gestureControl != null) {
                    touches = new Touch[1][1];
                    touches[0][0] = new Touch(new TouchPosition(motionEvent1), gestureControl);
                    gesture.setTouches(touches);
                    gestureControl.setId(new PropertyName(id, IdType.XPATH, id, GestureUtil.getInitialZIndex()));
                    gestureControl.setTlType(targetWidget);
                    gestureControl.setType(targetWidget);
                }
            }

            gesture.setEventInfo(eventInfo);
            gesture.setTouches(touches);

            if (LayoutUtil.canCaptureUserEvents(activity, Connect.INSTANCE.getCurrentLogicalPageName()) && LayoutUtil.canTakeScreenShot(activity, Connect.INSTANCE.getCurrentLogicalPageName())) {

                // TBD: No longer used? (updated to latest config files -- apparent change)
                // Thread.sleep(EOCore.getConfigItemLong("GestureConfirmedScreenshotDelay", TealeafEOLifecycleObject.getInstance()));
                gesture.setBase64Image(lastPageImage.getBase64Image());
            }
        } catch (Exception e) {
            com.tl.uic.util.LogInternal.logException(e, "Error trying to log gesture.");
        } finally {
            TLFCache.addMessage(gesture);
            TLFCache.flush(true);
        }
    }
}
