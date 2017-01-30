/* Copyright 2016 Siddhartha Das (bablu.boy@gmail.com)
*
* This file is part of Bookworm.
*
* Bookworm is free software: you can redistribute it
* and/or modify it under the terms of the GNU General Public License as
* published by the Free Software Foundation, either version 3 of the
* License, or (at your option) any later version.
*
* Bookworm is distributed in the hope that it will be
* useful, but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General
* Public License for more details.
*
* You should have received a copy of the GNU General Public License along
* with Nutty. If not, see http://www.gnu.org/licenses/.
*/

using Gtk;
using Gee;
using Granite.Widgets;

public const string GETTEXT_PACKAGE = "bookworm";

namespace BookwormApp {

	public class Bookworm:Granite.Application {
		public Gtk.Window window;
		public int exitCodeForCommand = 0;
		public static string bookworm_config_path = GLib.Environment.get_user_config_dir ()+"/bookworm";
		public static bool command_line_option_version = false;
		public static bool command_line_option_alert = false;
		public static bool command_line_option_debug = false;
		[CCode (array_length = false, array_null_terminated = true)]
		public static string command_line_option_monitor = "";
		public new OptionEntry[] options;
		public static Bookworm application;
		public Gtk.SearchEntry headerSearchBar;
		public StringBuilder spawn_async_with_pipes_output = new StringBuilder("");
		public WebKit.WebView aWebView;
		public ePubReader aReader;
		public Gtk.HeaderBar headerbar;
		public string BOOKWORM_CURRENT_STATE = BookwormApp.Constants.BOOKWORM_UI_STATES[0];
		public Gtk.Box bookSelection_ui_box;
		public Gtk.Box bookReading_ui_box;

		construct {
			application_id = "org.bookworm";
			flags |= ApplicationFlags.HANDLES_COMMAND_LINE;

			program_name = "Bookworm";
			app_years = "2016";

			build_version = Constants.bookworm_version;
			app_icon = "bookworm";
			main_url = "https://launchpad.net/bookworm";
			bug_url = "https://bugs.launchpad.net/bookworm";
			help_url = "https://answers.launchpad.net/bookworm";
			translate_url = "https://translations.launchpad.net/bookworm";

			about_documenters = { null };
			about_artists = { "Siddhartha Das <bablu.boy@gmail.com>" };
			about_authors = { "Siddhartha Das <bablu.boy@gmail.com>" };
			about_comments = _("An eBook Reader");
			about_translators = _("Launchpad Translators");
			about_license_type = Gtk.License.GPL_3_0;

			options = new OptionEntry[4];
			options[0] = { "version", 0, 0, OptionArg.NONE, ref command_line_option_version, _("Display version number"), null };
			options[3] = { "debug", 0, 0, OptionArg.NONE, ref command_line_option_debug, _("Run Bookworm in debug mode"), null };
			add_main_option_entries (options);
		}

		public Bookworm() {
			Intl.setlocale(LocaleCategory.MESSAGES, "");
			Intl.textdomain(GETTEXT_PACKAGE);
			Intl.bind_textdomain_codeset(GETTEXT_PACKAGE, "utf-8");
			Intl.bindtextdomain(GETTEXT_PACKAGE, "./locale");
			debug ("Completed setting Internalization...");
		}

		public static int main (string[] args) {
			Log.set_handler ("bookworm", GLib.LogLevelFlags.LEVEL_DEBUG, GLib.Log.default_handler);
			if("--debug" in args){
				Environment.set_variable ("G_MESSAGES_DEBUG", "all", true);
				debug ("Bookworm Application running in debug mode - all debug messages will be displayed");
			}
			application = new Bookworm();

			//Workaround to get Granite's --about & Gtk's --help working together
			if ("--help" in args || "-h" in args || "--monitor" in args || "--alert" in args || "--version" in args) {
				return application.processCommandLine (args);
			} else {
				Gtk.init (ref args);
				return application.run(args);
			}
		}

		public override int command_line (ApplicationCommandLine command_line) {
			activate();
			return 0;
		}

		private int processCommandLine (string[] args) {
			try {
				var opt_context = new OptionContext ("- bookworm");
				opt_context.set_help_enabled (true);
				opt_context.add_main_entries (options, null);
				unowned string[] tmpArgs = args;
				opt_context.parse (ref tmpArgs);
			} catch (OptionError e) {
				info ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
				info ("error: %s\n", e.message);
				return 0;
			}
			//check and run nutty based on command line option
			if(command_line_option_debug){
				debug ("Bookworm running in debug mode...");
			}
			if(command_line_option_version){
				print("\nbookworm version "+Constants.bookworm_version+" \n");
				return 0;
			}else{
				activate();
				return 0;
			}
		}

		public override void activate() {
			debug("Starting to activate Gtk Window for Bookworm...");
			window = new Gtk.Window ();
			add_window (window);
			//set window attributes
			window.set_default_size(1000, 600);
			window.set_border_width (Constants.SPACING_WIDGETS);
			window.set_position (Gtk.WindowPosition.CENTER);
			window.window_position = Gtk.WindowPosition.CENTER;
			//load state information from file
			loadBookwormState();
			//add window components
			create_headerbar(window);
			window.add(createBoookwormUI());
			window.show_all();
			toggleUIState();
			//load pictures
			try{

			}catch(GLib.Error e){
				warning("Failed to load icons/theme: "+e.message);
			}
			//Exit Application Event
			window.destroy.connect (() => {
				//save state information to file
				saveBookwormState();
			});
			debug("Completed loading Gtk Window for Bookworm...");
		}

		private void create_headerbar(Gtk.Window window) {
			debug("Starting creation of header bar..");
			headerbar = new Gtk.HeaderBar();
			headerbar.set_title(program_name);
			headerbar.subtitle = Constants.TEXT_FOR_SUBTITLE_HEADERBAR;
			headerbar.set_show_close_button(true);
			headerbar.spacing = Constants.SPACING_WIDGETS;
			window.set_titlebar (headerbar);
			//add menu items to header bar - content list button
			Gtk.Image library_view_button_image = new Gtk.Image ();
			library_view_button_image.set_from_file (Constants.LIBRARY_VIEW_IMAGE_LOCATION);
			Gtk.Button library_view_button = new Gtk.Button ();
			library_view_button.set_image (library_view_button_image);

			Gtk.Image content_list_button_image = new Gtk.Image ();
			content_list_button_image.set_from_file (Constants.CONTENTS_VIEW_IMAGE_LOCATION);
			Gtk.Button content_list_button = new Gtk.Button ();
			content_list_button.set_image (content_list_button_image);

			headerbar.pack_start(library_view_button);
			headerbar.pack_start(content_list_button);

			//add menu items to header bar - Menu
			headerbar.pack_end(createBookwormMenu(new Gtk.Menu ()));

			//Add a search entry to the header
			headerSearchBar = new Gtk.SearchEntry();
			headerSearchBar.set_text(Constants.TEXT_FOR_SEARCH_HEADERBAR);
			headerbar.pack_end(headerSearchBar);
			// Set actions for HeaderBar search
			headerSearchBar.search_changed.connect (() => {

			});
			library_view_button.clicked.connect (() => {
				//set UI for library view
				BOOKWORM_CURRENT_STATE = BookwormApp.Constants.BOOKWORM_UI_STATES[0];
				toggleUIState();
			});
			content_list_button.clicked.connect (() => {

			});
			debug("Completed loading HeaderBar sucessfully...");
		}

		public AppMenu createBookwormMenu (Gtk.Menu menu) {
			debug("Starting creation of Bookworm Menu...");
			Granite.Widgets.AppMenu app_menu;
			//Add sub menu items
			Gtk.MenuItem menuItemPrefferences = new Gtk.MenuItem.with_label(Constants.TEXT_FOR_HEADERBAR_MENU_PREFS);
			menu.add (menuItemPrefferences);
			Gtk.MenuItem menuItemExportToFile = new Gtk.MenuItem.with_label(Constants.TEXT_FOR_HEADERBAR_MENU_EXPORT);
			menu.add (menuItemExportToFile);
			app_menu = new Granite.Widgets.AppMenu.with_app(this, menu);

			//Add actions for menu items
			menuItemPrefferences.activate.connect(() => {

			});
			menuItemExportToFile.activate.connect(() => {

			});
			//Add About option to menu
			app_menu.show_about.connect (show_about);
			debug("Completed creation of Bookworm Menu sucessfully...");
			return app_menu;
		}

		public Gtk.Box createBoookwormUI() {
			debug("Starting to create main window components...");
			Gtk.Box main_ui_box = new Gtk.Box (Orientation.VERTICAL, 0);

			//Create the UI for selecting a book
			bookSelection_ui_box = new Gtk.Box (Orientation.VERTICAL, 0);
			//Create a box to display the book library
			Gtk.Box library_box = new Gtk.Box (Orientation.HORIZONTAL, 0);
			//Create a footer to add/remove books
			Gtk.Box add_remove_footer_box = new Gtk.Box (Orientation.HORIZONTAL, BookwormApp.Constants.SPACING_BUTTONS);
			//Set up Button for adding book
			Gtk.Image add_book_image = new Gtk.Image ();
			add_book_image.set_from_file (BookwormApp.Constants.ADD_BOOK_ICON_IMAGE_LOCATION);
			Gtk.Button add_book_button = new Gtk.Button ();
			add_book_button.set_image (add_book_image);
			//Set up Button for removing book
			Gtk.Image remove_book_image = new Gtk.Image ();
			remove_book_image.set_from_file (BookwormApp.Constants.REMOVE_BOOK_ICON_IMAGE_LOCATION);
			Gtk.Button remove_book_button = new Gtk.Button ();
			remove_book_button.set_image (remove_book_image);

			//Set up contents of the add/remove books footer label
			add_remove_footer_box.pack_start (add_book_button, false, true, 0);
			add_remove_footer_box.pack_start (remove_book_button, false, true, 0);

			//add all components to ui box for selecting a book
			bookSelection_ui_box.pack_start (library_box, true, true, 0);
      bookSelection_ui_box.pack_start (add_remove_footer_box, false, true, 0);

			//Create the UI for reading a selected book
			bookReading_ui_box = new Gtk.Box (Orientation.VERTICAL, 0);
			//create the webview to display page content
			aReader = new ePubReader();
			aWebView = aReader.getWebView();

			//create book reading footer
			Gtk.Box book_reading_footer_box = new Gtk.Box (Orientation.HORIZONTAL, 0);

			//Set up Button for previous page
			Gtk.Image back_button_image = new Gtk.Image ();
			back_button_image.set_from_file (BookwormApp.Constants.PREV_PAGE_ICON_IMAGE_LOCATION);
			Gtk.Button back_button = new Gtk.Button ();
			back_button.set_image (back_button_image);

			//Set up Button for next page
			Gtk.Image forward_button_image = new Gtk.Image ();
			forward_button_image.set_from_file (BookwormApp.Constants.NEXT_PAGE_ICON_IMAGE_LOCATION);
			Gtk.Button forward_button = new Gtk.Button ();
			forward_button.set_image (forward_button_image);

			//Set up contents of the footer label
			Gtk.Label pageNumberLabel = new Label("");
			book_reading_footer_box.pack_start (back_button, false, true, 0);
			book_reading_footer_box.pack_start (pageNumberLabel, true, true, 0);
			book_reading_footer_box.pack_end (forward_button, false, true, 0);

			//add all components to ui box for book reading
			bookReading_ui_box.pack_start (aWebView, true, true, 0);
      bookReading_ui_box.pack_start (book_reading_footer_box, false, true, 0);

			//Add all ui components to the main UI box
			main_ui_box.pack_start(bookSelection_ui_box, true, true, 0);
			main_ui_box.pack_end(bookReading_ui_box, true, true, 0);

			//Add all UI action listeners
			forward_button.clicked.connect (() => {
				ePubReader.pageChange (aWebView, aReader.currentPageNumber+1);
				pageNumberLabel.set_text((aReader.currentPageNumber+1).to_string() + " of " + "504");
				//check if the end of the book is reached and disable forward page button
				if(aReader.currentPageNumber+1 == aReader.readingListData.size){
					forward_button.set_sensitive(false);
				}
			});
			back_button.clicked.connect (() => {
				if(aReader.currentPageNumber > 0){
					ePubReader.pageChange (aWebView, aReader.currentPageNumber-1);
					pageNumberLabel.set_text((aReader.currentPageNumber-1).to_string() + " of " + "504");
				}
			});
			add_book_button.clicked.connect (() => {
				readSelectedBook();
			});
			remove_book_button.clicked.connect (() => {

			});

			//ensure all required set up is present
			ensureRequiredSetUp();

			debug("Completed creation of main windows components...");
			return main_ui_box;
		}

		public void ensureRequiredSetUp(){
			//check and create directory for extracting contents of ebook
	    BookwormApp.Utils.fileOperations("CREATEDIR", BookwormApp.Constants.EPUB_EXTRACTION_LOCATION, "", "");
		}

		public void readSelectedBook(){
			//reset the arraylist contaning the book details
			BookwormApp.ePubReader.readingListData.clear();
			BookwormApp.ePubReader.currentPageNumber = -1;
			//prepare the selected book for reading
			ePubReader.prepareBookForReading(window);
			//Update header title
			headerbar.subtitle = BookwormApp.ePubReader.bookTitle;
			//set UI for reading book
			BOOKWORM_CURRENT_STATE = BookwormApp.Constants.BOOKWORM_UI_STATES[1];
			toggleUIState();
			//Show first page of selected book
			ePubReader.pageChange (aWebView, aReader.currentPageNumber+1);
		}

		public void toggleUIState(){
			if(BOOKWORM_CURRENT_STATE == BookwormApp.Constants.BOOKWORM_UI_STATES[0]){
				//Only show the UI for selecting a book
				bookReading_ui_box.set_visible(false);
				bookSelection_ui_box.set_visible(true);
			}else{
				//Only show the UI for reading a book
				bookReading_ui_box.set_visible(true);
				bookSelection_ui_box.set_visible(false);
			}
		}

		public void saveBookwormState(){
			debug("Starting to save Bookworm state...");

		}

		public void loadBookwormState(){
			debug("Started loading Bookworm state...");

		}
	}
}
