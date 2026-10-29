struct Track {
    let title: String
    let artist: String
    let fileName: String
    let coverImageName: String
}

enum TrackLibrary {
    static let tracks: [Track] = [
        Track(title: "Soft Focus", artist: "Mira Vale", fileName: "soft_focus", coverImageName: "cover_soft_focus"),
        Track(title: "Tidal Glass", artist: "North Array", fileName: "tidal_glass", coverImageName: "cover_tidal_glass"),
        Track(title: "Ochre Sky", artist: "Sola Forma", fileName: "ochre_sky", coverImageName: "cover_ochre_sky"),
        Track(title: "Folded Light", artist: "Mira Vale", fileName: "folded_light", coverImageName: "cover_folded_light"),
        Track(title: "Open Water", artist: "North Array", fileName: "open_water", coverImageName: "cover_open_water"),
        Track(title: "Faint Signal", artist: "Quiet Relay", fileName: "faint_signal", coverImageName: "cover_faint_signal"),
        Track(title: "Slow Arc", artist: "Sola Forma", fileName: "slow_arc", coverImageName: "cover_slow_arc"),
        Track(title: "Parallel Lines", artist: "Quiet Relay", fileName: "parallel_lines", coverImageName: "cover_parallel_lines"),
        Track(title: "Lunar Echo", artist: "Aster North", fileName: "lunar_echo", coverImageName: "cover_lunar_echo"),
        Track(title: "Night Ferry", artist: "Aster North", fileName: "night_ferry", coverImageName: "cover_night_ferry"),
    ]
}
