from pathlib import Path

home = Path('lib/screens/home/home_screen.dart')
s = home.read_text()

old = """  bool _showFavoritesOnly = false;\n  bool _isSearching = false;\n  String _searchQuery = '';\n"""
new = """  bool _showFavoritesOnly = false;\n  bool _isSearching = false;\n  // false: project/folder name keyword search, true: project tag search.\n  // The search bar toggle swaps these modes like a play/pause control.\n  bool _searchByTag = false;\n  String _searchQuery = '';\n"""
assert old in s, 'home search state anchor not found'
s = s.replace(old, new, 1)

old = """            leadingWidth: 96,\n"""
new = """            // While searching, temporarily hide the hamburger button and shrink\n            // the leading area to the back button only.\n            leadingWidth: _isSearching ? 48 : 96,\n"""
assert old in s, 'leadingWidth anchor not found'
s = s.replace(old, new, 1)

old = """                IconButton(\n                  icon: const Icon(Icons.menu),\n                  tooltip: MaterialLocalizations.of(\n                    context,\n                  ).openAppDrawerTooltip,\n                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),\n                ),\n"""
new = """                if (!_isSearching)\n                  IconButton(\n                    icon: const Icon(Icons.menu),\n                    tooltip: MaterialLocalizations.of(\n                      context,\n                    ).openAppDrawerTooltip,\n                    onPressed: () => _scaffoldKey.currentState?.openDrawer(),\n                  ),\n"""
assert old in s, 'hamburger anchor not found'
s = s.replace(old, new, 1)

old = """            title: _isSearching\n                ? TextField(\n                    controller: _searchController,\n                    autofocus: true,\n                    decoration: InputDecoration(\n                      hintText: l10n.homeSearchHint,\n                      border: InputBorder.none,\n                    ),\n                    onChanged: (v) => setState(() => _searchQuery = v),\n                  )\n"""
new = """            title: _isSearching\n                ? Row(\n                    children: [\n                      // The icon always represents the mode we can switch TO:\n                      // keyword mode -> tag icon, tag mode -> search icon.\n                      IconButton(\n                        icon: Icon(\n                          _searchByTag ? Icons.search : Icons.sell_outlined,\n                        ),\n                        tooltip: _searchByTag\n                            ? l10n.homeSearchHint\n                            : l10n.projectDetailTagsQuickAction,\n                        onPressed: () =>\n                            setState(() => _searchByTag = !_searchByTag),\n                      ),\n                      Expanded(\n                        child: TextField(\n                          controller: _searchController,\n                          autofocus: true,\n                          decoration: InputDecoration(\n                            hintText: _searchByTag\n                                ? l10n.projectDetailTagsQuickAction\n                                : l10n.homeSearchHint,\n                            border: InputBorder.none,\n                          ),\n                          onChanged: (v) =>\n                              setState(() => _searchQuery = v),\n                        ),\n                      ),\n                    ],\n                  )\n"""
assert old in s, 'search title anchor not found'
s = s.replace(old, new, 1)

old = """                  onPressed: () => setState(() {\n                    _isSearching = false;\n                    _searchQuery = '';\n                    _searchController.clear();\n                  }),\n"""
new = """                  onPressed: () => setState(() {\n                    _isSearching = false;\n                    _searchByTag = false;\n                    _searchQuery = '';\n                    _searchController.clear();\n                  }),\n"""
assert old in s, 'search close anchor not found'
s = s.replace(old, new, 1)

old = """                  onPressed: () => setState(() => _isSearching = true),\n"""
new = """                  onPressed: () => setState(() {\n                    _isSearching = true;\n                    _searchByTag = false;\n                  }),\n"""
assert old in s, 'search open anchor not found'
s = s.replace(old, new, 1)

old = """                        if (_searchQuery.trim().isEmpty) _buildBreadcrumb(),\n"""
new = """                        if (!_isSearching) _buildBreadcrumb(),\n"""
assert old in s, 'breadcrumb anchor not found'
s = s.replace(old, new, 1)

old = """                            searchQuery: _searchQuery,\n                            currentFolderId: _currentFolderId,\n"""
new = """                            searchQuery: _searchQuery,\n                            searchByTag: _searchByTag,\n                            currentFolderId: _currentFolderId,\n"""
assert old in s, 'ProjectListWidget search args anchor not found'
s = s.replace(old, new, 1)

home.write_text(s)

project_list = Path('lib/screens/home/widgets/project_list_widget.dart')
s = project_list.read_text()

old = """  final bool showFavoritesOnly;\n  final String searchQuery;\n"""
new = """  final bool showFavoritesOnly;\n  final String searchQuery;\n  // When true, searchQuery is matched against project tags instead of names.\n  // Folders intentionally do not participate because they have no tags.\n  final bool searchByTag;\n"""
assert old in s, 'project list field anchor not found'
s = s.replace(old, new, 1)

old = """    this.showFavoritesOnly = false,\n    this.searchQuery = '',\n    this.onPickProject,\n"""
new = """    this.showFavoritesOnly = false,\n    this.searchQuery = '',\n    this.searchByTag = false,\n    this.onPickProject,\n"""
assert old in s, 'project list ctor anchor not found'
s = s.replace(old, new, 1)

old = """    final query = searchQuery.trim().toLowerCase();\n\n    List<_Entry> entries;\n    if (query.isNotEmpty) {\n      // 検索時はフォルダ階層を無視して全体から名前一致するものを表示する\n      // （検索対象：プロジェクト名 / フォルダ名）。\n      entries = [\n        ...allFolders\n            .where((f) => f.name.toLowerCase().contains(query))\n            .map((f) => _Entry.folder(f)),\n        ...source\n            .where((p) => p.name.toLowerCase().contains(query))\n            .map((p) => _Entry.project(p)),\n      ];\n    } else {\n"""
new = """    final rawQuery = searchQuery.trim().toLowerCase();\n    // Accept both `tag` and `#tag` input in tag mode.\n    final query = searchByTag && rawQuery.startsWith('#')\n        ? rawQuery.substring(1).trimLeft()\n        : rawQuery;\n\n    List<_Entry> entries;\n    if (query.isNotEmpty) {\n      // Search ignores folder hierarchy and scans all projects. Keyword mode\n      // keeps the existing project/folder-name behavior; tag mode returns only\n      // projects whose saved tags contain the query.\n      if (searchByTag) {\n        entries = source\n            .where(\n              (p) => p.tags.any(\n                (tag) => tag.trim().toLowerCase().contains(query),\n              ),\n            )\n            .map((p) => _Entry.project(p))\n            .toList();\n      } else {\n        entries = [\n          ...allFolders\n              .where((f) => f.name.toLowerCase().contains(query))\n              .map((f) => _Entry.folder(f)),\n          ...source\n              .where((p) => p.name.toLowerCase().contains(query))\n              .map((p) => _Entry.project(p)),\n        ];\n      }\n    } else {\n"""
assert old in s, 'project list filter anchor not found'
s = s.replace(old, new, 1)

project_list.write_text(s)

project_detail = Path('lib/screens/project/project_detail_screen.dart')
s = project_detail.read_text()

old = """              ),\n              const SizedBox(height: 24),\n              Padding(\n                padding: const EdgeInsets.only(left: 4, bottom: 8),\n                child: Text(\n                  l10n.projectDetailInfoSectionTitle,\n"""
new = """              ),\n              if (project.tags.isNotEmpty) ...[\n                const SizedBox(height: 24),\n                Padding(\n                  padding: const EdgeInsets.only(left: 4, bottom: 8),\n                  child: Text(\n                    l10n.projectDetailTagsQuickAction,\n                    style: TextStyle(\n                      fontSize: 13,\n                      fontWeight: FontWeight.w700,\n                      fontFamily: 'Kuramubon',\n                      fontFamilyFallback: kHeadingFontFallback,\n                      color: Theme.of(context).colorScheme.onSurfaceVariant,\n                    ),\n                  ),\n                ),\n                Wrap(\n                  spacing: 8,\n                  runSpacing: 8,\n                  children: project.tags\n                      .map(\n                        (tag) => Chip(\n                          avatar: const Icon(Icons.sell_outlined, size: 16),\n                          label: Text('#$tag'),\n                        ),\n                      )\n                      .toList(),\n                ),\n              ],\n              const SizedBox(height: 24),\n              Padding(\n                padding: const EdgeInsets.only(left: 4, bottom: 8),\n                child: Text(\n                  l10n.projectDetailInfoSectionTitle,\n"""
assert old in s, 'project detail tag display anchor not found'
s = s.replace(old, new, 1)

project_detail.write_text(s)
