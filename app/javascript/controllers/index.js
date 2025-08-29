// Use the importmap specifier for the controllers application so that
// precompiled bundles and the browser will resolve it via the importmap
// (avoids relative './application' which becomes '/assets/controllers/application')
import { application } from "controllers/application"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

eagerLoadControllersFrom("controllers", application)
