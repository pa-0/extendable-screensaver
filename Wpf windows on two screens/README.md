# Display a WPF Application on Two Screens
<sup><em>Originally posted at https://www.codeproject.com/Articles/1165544/Wpf-windows-on-two-screens</em></sup>

In this article, you will learn how to position WPF window on secondary monitor or show two windows on two monitors.

## Introduction

The post shows how to position WPF window on secondary monitor or show two windows on two monitors. The post contains the complete code and we discuss how to address several scenarios.

There are the following disclaimers:

- I have provided code and conclusions based on empirical results, so I could be wrong or describe things incorrectly. 
- The code was tested on a computer with two monitors, so three and more monitors could behave differently.
- There are many topics concerning how to show or manipulate by the secondary monitor in WPF application. The post doesn't include these links, as it may be easily Googled.
- The original post contains screenshots from a computer with two displays.

 <p><a href="https://www.codeproject.com/KB/dialog/1165544/Screen1.png"><img src="https://www.codeproject.com/KB/dialog/1165544/Screen1.png" style="width: 300px; height: 386px"></a> <a href="https://www.codeproject.com/KB/dialog/1165544/Screen2.png"><img src="https://www.codeproject.com/KB/dialog/1165544/Screen2.png" style="width: 300px; height: 386px"></a></p>

<p><a href="https://www.codeproject.com/KB/dialog/1165544/Window100-100.png"><img src="https://www.codeproject.com/KB/dialog/1165544/Window100-100.png" style="width: 583px; height: 226px"></a></p>




### Features
The application demonstrates the following features:

- Output maximized windows on all displays
- Window contains list box with sizes of screens from system parameters and Screen class
- Using of dependency container

### Background
The solution uses C#6, .NET 4.6.1, WPF with MVVM pattern, System.Windows.Forms, System.Drawing, NuGet packages Unity and Ikc5.TypeLibrary.

## Solution

The solution contains one WPF application project. From the WPF application, all screens are considered as one "virtual" screen. In order to position window, it is necessary set window coordinates in "current" screen size. SystemParameters provides physical resolution of the primary screen, but according to WPF architecture, the position of elements should not rely on physical dimensions of the display. The main issue is that the exact value of "current" screen size depends on various factors. For example, they include text size from Windows' settings, how user connects to computer - by remote access or locally, and so on.

Screen class from System.Windows.Forms library provides useful property, Screen[] AllScreens. It allows to enumerate all screens and reads their working area. But coordinates of non-primary screen are set according to "current" text size of the primary window.

### `Application`

As windows are created manually, StartupUri should be removed from App.xaml. Method OnStartup executes the following code:

```csharp
init Unity container
```

Calculate current text size of the primary screen as ratio between `Screen.PrimaryScreen.WorkingArea` and `SystemParameters.PrimaryScreen`

For each screen, create window, position at current screen, show and maximize

```csharp
public partial class App : Application
{
    private void InitContainer(IUnityContainer container)
    {
        container.RegisterType<ILogger, EmptyLogger>();
        container.RegisterType<IMainWindowModel, MainWindowModel>();
    }

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        IUnityContainer container = new UnityContainer();
        InitContainer(container);

        var logger = container.Resolve<ILogger>();
        logger.Log($"There are {Screen.AllScreens.Length} screens");

        // calculates text size in that main window (i.e. 100%, 125%,...)
        var ratio = 
           Math.Max(Screen.PrimaryScreen.WorkingArea.Width / 
                           SystemParameters.PrimaryScreenWidth,
                    Screen.PrimaryScreen.WorkingArea.Height / 
                           SystemParameters.PrimaryScreenHeight);

        var pos = 0;
        foreach (var screen in Screen.AllScreens)
        {
            logger.Log(
                $"#{pos + 1} screen, size = ({screen.WorkingArea.Left}, 
                {screen.WorkingArea.Top}, {screen.WorkingArea.Width}, 
                                          {screen.WorkingArea.Height}), " +
                (screen.Primary ? "primary screen" : "secondary screen"));

            // Show automata at all screen
            var mainViewModel = container.Resolve<IMainWindowModel>(
                new ParameterOverride("backgroundColor", _screenColors[Math.Min
                                      (pos++, _screenColors.Length - 1)]),
                new ParameterOverride("primary", screen.Primary),
                new ParameterOverride("displayName", screen.DeviceName));

            var window = new MainWindow(mainViewModel);
            if (screen.Primary)
                Current.MainWindow = window;

            window.Left = screen.WorkingArea.Left / ratio;
            window.Top = screen.WorkingArea.Top / ratio;
            window.Width = screen.WorkingArea.Width / ratio;
            window.Height = screen.WorkingArea.Height / ratio;
            window.Show();
            window.WindowState = WindowState.Maximized;
        }
        Current.ShutdownMode = ShutdownMode.OnMainWindowClose;
    }

    private readonly Color[] _screenColors =
    {
        Colors.LightGray, Colors.DarkGray, 
        Colors.Gray, Colors.SlateGray, Colors.DarkSlateGray
    };
}
```

### `MainWindow`

Main window contains ListView that shows the list of ScreenRectangle models from MainWindowModel view model. In order to show window on expected screen, it should have the following properties:

```xml
WindowStartupLocation="Manual"
WindowState="Normal"
```

In addition, we remove caption bar and make window non-resizable:

```xml
WindowStyle="None"
ResizeMode="NoResize"
```

If comment line #45 in `App.xaml.cs`:

```csharp
window.WindowState = WindowState.Maximized;
```

then window will occupy the whole screen except taskbar.

### `MainWindowModel`

`MainWindowModel` class implements `IMainWindowModel` interface:

```csharp
public interface IMainWindowModel
{
    /// <summary>
    /// Background color.
    /// </summary>
    Color BackgroundColor { get; }
    /// <summary>
    /// Width of the view.
    /// </summary>
    double ViewWidth { get; set; }
    /// <summary>
    /// Height of the view.
    /// </summary>
    double ViewHeight { get; set; }
    /// <summary>
    /// Set of rectangles.
    /// </summary>
    ObservableCollection<ScreenRectangle> Rectangles { get; }
}
```

Background color is used to colorize window and distinct them at different screens. ViewHeight and ViewWidth are bound to attached properties in order to obtain view size in view model (the code is taken from Pushing read-only GUI properties back into ViewModel). ScreenRectangle class looks like derived class from Tuple<string, Rectangle> that implements NotifyPropertyChanged interface:

```csharp
public class ScreenRectangle : BaseNotifyPropertyChanged
{
    protected ScreenRectangle()
    {
        Name = string.Empty;
        Bounds = new RectangleF();
    }

    public ScreenRectangle(string name, RectangleF bounds)
    {
        Name = name;
        Bounds = bounds;
    }

    public ScreenRectangle(string name, double left, double top, double width, double height)
        : this(name, new RectangleF((float)left, (float)top, (float)width, (float)height))
    {
    }

    public ScreenRectangle(string name, double width, double height)
        : this(name, new RectangleF(0, 0, (float)width, (float)height))
    {
    }

    #region Public properties

    private string _name;
    private RectangleF _bounds;

    public string Name
    {
        get { return _name; }
        set { SetProperty(ref _name, value); }
    }

    public RectangleF Bounds
    {
        get { return _bounds; }
        set { SetProperty(ref _bounds, value); }
    }

    #endregion Public properties

    public void SetSize(double width, double height)
    {
        Bounds = new RectangleF(Bounds.Location, new SizeF((float)width, (float)height));
    }
}
```

## Update 1

The sample application was updated. Now it shows more system parameters and some sizes and dimensions are commented.

The main changes were done in the constructor of MainWindowModel class.

```csharp
public MainWindowModel(Color backgroundColor, bool primary, string displayName)
{
	this.SetDefaultValues();
	BackgroundColor = backgroundColor;

	_rectangles = new ObservableCollection<screenrectangle>(new[]
	{
		new ScreenRectangle(ScreenNames.View, ViewWidth, ViewHeight,
			"View uses border with BorderThickness='3', 
             and its size is lesser than screen size at 6px at each dimension")
	});
	if( primary)
	{
		_rectangles.Add(new ScreenRectangle(ScreenNames.PrimaryScreen,
			(float)SystemParameters.PrimaryScreenWidth, 
            (float)SystemParameters.PrimaryScreenHeight,
			"'Emulated' screen dimensions for Wpf applications"));
		_rectangles.Add(new ScreenRectangle(ScreenNames.FullPrimaryScreen,
			(float) SystemParameters.FullPrimaryScreenWidth, 
            (float) SystemParameters.FullPrimaryScreenHeight,
			"Height difference with working area height depends on locale"));
		_rectangles.Add(new ScreenRectangle(ScreenNames.VirtualScreen,
			(float) SystemParameters.VirtualScreenLeft, 
            (float) SystemParameters.VirtualScreenTop,
			(float) SystemParameters.VirtualScreenWidth, 
            (float) SystemParameters.VirtualScreenHeight));
		_rectangles.Add(new ScreenRectangle(ScreenNames.WorkingArea,
			SystemParameters.WorkArea.Width, SystemParameters.WorkArea.Height,
			"40px is holded for the taskbar height"));
		_rectangles.Add(new ScreenRectangle(ScreenNames.PrimaryWorkingArea,
			Screen.PrimaryScreen.WorkingArea.Left, Screen.PrimaryScreen.WorkingArea.Top,
			Screen.PrimaryScreen.WorkingArea.Width, 
            Screen.PrimaryScreen.WorkingArea.Height));
	}

	foreach (var screeen in Screen.AllScreens)
	{
		if (!primary && !Equals(screeen.DeviceName, displayName))
			continue;
		_rectangles.Add(new ScreenRectangle($"Screen \"{screeen.DeviceName}\"", 
                        screeen.WorkingArea,
			"Physical dimensions"));
	}
}
```

## Update 2

Recently, we faced up with the issue when fixed size dialog in WPF application at Windows 7/10 English works well, but when user uses Windows 7 Chinese, some controls are cut or not shown. There exists the solution for WinForm applications, but it is not suitable for WPF applications, as they use another scaling approach. The issue was fixed by two steps:
- Fixed size was replaced by the desired size that is calculated by UserControl.Measuze() method.
- It was noticed that Full primary screen size is less than Work area size, but difference depends on locale.
  - Let:
    ```csharp
     localeDelta = SystemParameters.WorkArea.Height - SystemParameters.FullPrimaryScreenHeight
    ```
  - Then:
    - for Windows 7/10 Englishlocale
      ```csharp
      localeDelta == 13.14, 
      ```
      and it depends a little on screen dimensions
    - for Windows 7 Chinese locale 
      ```csharp
      localeDelta == 22
      ```
Unfortunately, I didn't find any information about the origin of this value, but it was enough to increase the height of the dialog window by localeDelta.
