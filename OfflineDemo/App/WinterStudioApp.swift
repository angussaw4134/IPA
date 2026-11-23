import SwiftUI

@main
struct WinterStudioApp: App {
    var body: some Scene {
        WindowGroup {
            StudioRoot()
                .preferredColorScheme(.dark)
        }
    }
}

enum StudioStyle {
    static let background = Color(red: 0.035, green: 0.075, blue: 0.11)
    static let surface = Color(red: 0.075, green: 0.14, blue: 0.18)
    static let mint = Color(red: 0.64, green: 0.94, blue: 0.80)
}

struct DemoLabel: View {
    var body: some View {
        Text("DEMO TEST\nNOT REAL ID")
            .font(.system(size: 27, weight: .heavy, design: .rounded))
            .multilineTextAlignment(.center)
            .foregroundStyle(.yellow)
            .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .accessibilityIdentifier("demo-label")
    }
}

struct StudioRoot: View {
    @AppStorage("studio.activationHash") private var activationHash = ""
    @AppStorage("studio.nickname") private var nickname = "Alex Sample"
    @AppStorage("studio.savedActivities") private var savedActivities = ""
    @AppStorage("studio.privacyEnabled") private var privacyEnabled = true
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab = 0
    @State private var accessCode = ""
    @State private var accessError = ""
    @State private var showSettings = false
    @State private var showGuide = false
    @State private var showTicket = false
    @State private var confirmReset = false

    private var unlocked: Bool { DemoAccess.contains(hash: activationHash) }
    private var saved: [String] { savedActivities.split(separator: "|").map(String.init) }
    private var displayName: String { nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Alex Sample" : nickname }

    var body: some View {
        ZStack {
            StudioStyle.background.ignoresSafeArea()
            if unlocked {
                TabView(selection: $selectedTab) {
                    home.tabItem { Label("Home", systemImage: "house.fill") }.tag(0)
                    explore.tabItem { Label("Explore", systemImage: "sparkles") }.tag(1)
                    wallet.tabItem { Label("Wallet", systemImage: "ticket.fill") }.tag(2)
                }
                .tint(StudioStyle.mint)
            } else {
                accessScreen
            }
            if privacyEnabled && selectedTab == 2 && scenePhase != .active {
                StudioStyle.background.ignoresSafeArea()
                VStack(spacing: 14) {
                    Image(systemName: "snowflake").font(.system(size: 48))
                    Text("Winter Studio").font(.title.bold())
                    Text("Your demo is paused.").foregroundStyle(.secondary)
                }
            }
            DemoLabel()
        }
        .sheet(isPresented: $showSettings) { settings.overlay { DemoLabel() } }
        .sheet(isPresented: $showGuide) { guide.overlay { DemoLabel() } }
        .sheet(isPresented: $showTicket) { ticketSheet.overlay { DemoLabel() } }
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "winterstudiodemo", url.host?.lowercased() == "home" else { return }
            selectedTab = 0
        }
    }

    private var accessScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Image(systemName: "snowflake").font(.system(size: 52)).foregroundStyle(StudioStyle.mint)
                Text("WINTER STUDIO / OFFLINE").font(.caption.bold()).tracking(2).foregroundStyle(StudioStyle.mint)
                Text("A little winter.\nAll on your phone.").font(.system(size: 38, weight: .bold, design: .rounded))
                Text("A fictional, self-contained app playground. Enter a demo code to explore.").foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Demo access code").font(.headline)
                    TextField("WINTER-…", text: $accessCode)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .padding().background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 14))
                        .accessibilityIdentifier("access-code")
                        .onSubmit(activate)
                    Button(action: activate) { Text("Open demo").frame(maxWidth: .infinity).padding(8) }
                        .buttonStyle(.borderedProminent).tint(StudioStyle.mint).foregroundStyle(.black)
                        .accessibilityIdentifier("open-demo")
                    if !accessError.isEmpty { Text(accessError).font(.callout).foregroundStyle(.orange).accessibilityIdentifier("access-error") }
                }
                Text("No website. No account. No tracking.\nDemo codes are checked on this device only.")
                    .font(.footnote).foregroundStyle(.secondary)
                Text("FICTIONAL DEMONSTRATION • NOT VALID IDENTIFICATION")
                    .font(.caption2.bold()).foregroundStyle(.yellow)
            }.padding(28).padding(.vertical, 36)
        }.scrollDismissesKeyboard(.interactively)
    }

    private func activate() {
        guard let hash = DemoAccess.accept(accessCode) else {
            accessError = "That demo code is not recognised. Check it and try again."
            return
        }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            activationHash = hash
            accessError = ""
            accessCode = ""
        }
    }

    private var home: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack {
                        Label("WINTER STUDIO", systemImage: "snowflake").font(.caption.bold()).tracking(1)
                        Spacer()
                        Text("OFFLINE").font(.caption2.bold()).foregroundStyle(StudioStyle.mint)
                    }
                    Text("Hello,\n\(displayName).")
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .accessibilityIdentifier("welcome")
                    Text("A quieter place to explore.").foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 24) {
                        HStack {
                            Image(systemName: "mountain.2.fill").font(.system(size: 62)).foregroundStyle(StudioStyle.mint)
                            Spacer()
                            Image(systemName: "sparkles").font(.largeTitle).foregroundStyle(.yellow)
                        }
                        Text("Your winter,\nyour pace.").font(.largeTitle.bold())
                        Text("Discover fictional activities and save favourites to this phone.").foregroundStyle(.secondary)
                        Button("Explore activities") { selectedTab = 1 }.buttonStyle(.borderedProminent).tint(StudioStyle.mint).foregroundStyle(.black)
                    }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                        .background(StudioStyle.surface.gradient, in: RoundedRectangle(cornerRadius: 28))
                    HStack(spacing: 12) {
                        stat("Saved", value: "\(saved.count)", icon: "bookmark.fill")
                        stat("Connection", value: "Not needed", icon: "wifi.slash")
                    }
                    Button { showGuide = true } label: {
                        Label("How this demo works", systemImage: "questionmark.circle").frame(maxWidth: .infinity, alignment: .leading).padding()
                    }.buttonStyle(.bordered).tint(StudioStyle.mint)
                }.padding(24)
            }
            .background(StudioStyle.background)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
                    .accessibilityLabel("Settings")
            } }
        }
    }

    private func stat(_ label: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon).foregroundStyle(StudioStyle.mint)
            Text(value).font(.headline)
            Text(label).font(.caption).foregroundStyle(.secondary)
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private var explore: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Make a little time.").font(.largeTitle.bold())
                    Text("Sample experiences, imagined for this demo. Nothing here is a real booking.").foregroundStyle(.secondary)
                    ForEach(DemoActivity.all) { activity in
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: activity.symbol).font(.largeTitle).foregroundStyle(StudioStyle.mint)
                                Spacer()
                                Text("FICTIONAL").font(.caption2.bold()).foregroundStyle(.yellow)
                            }
                            Text(activity.title).font(.title2.bold())
                            Text(activity.detail).foregroundStyle(.secondary)
                            Button {
                                var values = saved
                                if values.contains(activity.id) { values.removeAll { $0 == activity.id } }
                                else { values.append(activity.id) }
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) { savedActivities = values.joined(separator: "|") }
                            } label: {
                                Label(saved.contains(activity.id) ? "Saved" : "Save activity", systemImage: saved.contains(activity.id) ? "bookmark.fill" : "bookmark")
                            }.buttonStyle(.bordered).tint(StudioStyle.mint).accessibilityIdentifier("save-\(activity.id)")
                        }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
                            .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 24))
                    }
                }.padding(24)
            }.background(StudioStyle.background).navigationTitle("Explore")
        }
    }

    private var wallet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Only make-believe.\nAlways yours.").font(.largeTitle.bold())
                    Button { showTicket = true } label: {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack { Image(systemName: "snowflake"); Spacer(); Text("SAMPLE ONLY").font(.caption.bold()) }
                            Text("Winter festival").font(.title.bold())
                            Text("A fictional event pass").font(.headline)
                            Divider()
                            Label("Preview sample", systemImage: "arrow.up.right")
                        }.padding(26).frame(maxWidth: .infinity, alignment: .leading)
                            .background(StudioStyle.mint.gradient, in: RoundedRectangle(cornerRadius: 24))
                            .foregroundStyle(StudioStyle.background)
                    }.buttonStyle(.plain).accessibilityIdentifier("sample-pass")
                    Text("No admission, identity or credential validity.").font(.footnote).foregroundStyle(.secondary)
                    Text("Saved activities").font(.title2.bold())
                    if saved.isEmpty {
                        Text("Save an activity in Explore and it will appear here.").foregroundStyle(.secondary)
                    }
                    ForEach(DemoActivity.all.filter { saved.contains($0.id) }) { item in
                        Label(item.title, systemImage: item.symbol).padding().frame(maxWidth: .infinity, alignment: .leading)
                            .background(StudioStyle.surface, in: RoundedRectangle(cornerRadius: 16))
                    }
                }.padding(24)
            }.background(StudioStyle.background).navigationTitle("Wallet")
        }
    }

    private var ticketSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Image(systemName: "gift.fill").font(.system(size: 76)).foregroundStyle(StudioStyle.mint)
                    Text("Winter festival").font(.largeTitle.bold())
                    Text("FICTIONAL SAMPLE PASS").font(.headline).foregroundStyle(.yellow)
                    Text("Guest: Alex Sample\nLocation: Imaginary Snow Park\nReference: SAMPLE-001").font(.title3).lineSpacing(12)
                    Text("This is a design demonstration, not a ticket, identification document or proof of access. There is no scannable code or verification service.").foregroundStyle(.secondary)
                }.padding(28)
            }.background(StudioStyle.background).navigationTitle("Sample preview")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showTicket = false } } }
        }
    }

    private var settings: some View {
        NavigationStack {
            Form {
                Section("Your local profile") {
                    TextField("Display nickname", text: $nickname).accessibilityIdentifier("nickname")
                        .onChange(of: nickname) { value in if value.count > 40 { nickname = String(value.prefix(40)) } }
                    Text("Use a nickname. This is stored only on your phone.").font(.caption)
                }
                Section("Privacy") {
                    Toggle("Cover Wallet when leaving the app", isOn: $privacyEnabled)
                    Text("This does not prevent screenshots while the app is open.").font(.caption)
                }
                Section("Offline storage") {
                    Text("The app has no website, admin panel, analytics or remote database. Settings and saved activities stay on this installation.")
                    Text("Deleting the app can remove your settings. Reinstall over the existing app with the same bundle ID and signing account to preserve them.")
                }
                Section("Demo access") {
                    Text("Codes are validated locally. They are reusable and cannot be revoked remotely or restricted to one device.")
                    Button("Lock demo") { activationHash = ""; showSettings = false; selectedTab = 0 }
                    Button("Reset local demo data", role: .destructive) { confirmReset = true }
                }
            }.navigationTitle("Settings")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showSettings = false } } }
                .confirmationDialog("Reset this demo?", isPresented: $confirmReset, titleVisibility: .visible) {
                    Button("Reset local data", role: .destructive) {
                        nickname = "Alex Sample"; savedActivities = ""; privacyEnabled = true
                        activationHash = ""; showSettings = false; selectedTab = 0
                    }
                } message: { Text("Your saved activities and nickname will be removed from this installation.") }
        }
    }

    private var guide: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Text("Everything travels with you.").font(.largeTitle.bold())
                    guideItem("01 / Open", "Enter one of the provided demo codes. It works without an internet connection.")
                    guideItem("02 / Explore", "Browse three fictional winter activities. Save or remove favourites instantly.")
                    guideItem("03 / Keep", "Wallet holds your favourites and a fictional sample event pass. It is not valid identification or admission.")
                    guideItem("04 / Make it yours", "Open Settings on Home to change your nickname or privacy preference. All settings stay on your phone.")
                    guideItem("05 / Update", "New features require an updated IPA. There are no live website updates or online support tickets in this build.")
                    guideItem("06 / Install", "The unsigned IPA must be signed with your own sideloading tool. Signing and refresh rules still apply even though the app works offline.")
                }.padding(26)
            }.background(StudioStyle.background).navigationTitle("Quick guide")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showGuide = false } } }
        }
    }

    private func guideItem(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(StudioStyle.mint)
            Text(text).foregroundStyle(.secondary)
        }
    }
}

struct DemoActivity: Identifiable {
    let id: String
    let title: String
    let symbol: String
    let detail: String
    static let all = [
        DemoActivity(id: "lights", title: "Evening lights", symbol: "sparkles", detail: "An imaginary walk through a garden of winter lights."),
        DemoActivity(id: "cocoa", title: "Cocoa corner", symbol: "cup.and.saucer.fill", detail: "A fictional cosy cafe for a quiet afternoon."),
        DemoActivity(id: "gifts", title: "Little gift market", symbol: "gift.fill", detail: "A made-up festive market full of small discoveries.")
    ]
}
